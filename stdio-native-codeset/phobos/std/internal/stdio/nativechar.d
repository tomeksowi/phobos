// Written in the D programming language.

/*
 * Encoder & decoder for system-native codeset.
 *
 * struct NativeCodesetDecoder:
 *   Converts native characters into the corresponding Unicode code points
 *   character-by-character.
 *
 * struct NativeCodesetEncoder:
 *   Converts UTF string into the corresponding native string by chunk.
 *
 *
 * This module is _not_ intended for general codeset convertion.  Its purpose
 * is to provide means of convertion between Unicode and system native codeset
 * using system functions:
 *
 *   Windows ... WideCharToMultiByte and MultiByteToWideChar
 *     POSIX ... iconv
 */

//          Copyright Shin Fujishiro 2010.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

module std.internal.stdio.nativechar;

import std.algorithm;
import std.array;
import std.conv;
import std.exception;
import std.range  : isInputRange, isOutputRange, ElementType;
import std.string : toStringz;
import std.traits : isSomeString, isArray;
import std.utf    : isValidDchar, stride, decode, putUTF;
import std.variant;

version (Windows)
{
    import core.sys.windows.windows;
    import std.windows.syserror;

    enum
    {
        ERROR_INVALID_PARAMETER   =  87,
        ERROR_INSUFFICIENT_BUFFER = 122,
    }
    enum CP_UTF8 = 65001;
}
else version (Posix)
{
    import core.stdc.errno;
    import core.stdc.locale;

    import core.sys.posix.iconv;
    import core.sys.posix.langinfo;

    debug = USE_LIBICONV;
}


version (unittest) private
{
    // For testing converter outputs.
    struct NaiveCatenator(E)
    {
        E[] data;
        void put(in E[] str) { data ~= str; }
    }
}


//----------------------------------------------------------------------------//

debug (USE_LIBICONV) extern(C) @system
{
    alias void* iconv_t;

    iconv_t iconv_open(in char*, in char*);
    size_t  iconv(iconv_t, in ubyte**, size_t*, ubyte**, size_t*);
    int     iconv_close(iconv_t);

    pragma(lib, "iconv");
}


private enum Transcoder
{
    none,
    WinNLS, // UTF-16 <--> native w/ MultiByteToWideChar & WideCharToMultiByte
    iconv,  // UTF-8  <--> native w/ iconv
}

version (Windows)
{
    enum backingTranscoder = Transcoder.WinNLS;
}
else version (Posix)
{
    enum backingTranscoder = is(iconv_t) ? Transcoder.iconv : Transcoder.none;

    // @@@ workaround: static if (is(iconv_t)) doesn't work
    version (  linux) version = HAVE_ICONV;
    version (    OSX) version = HAVE_ICONV;
    version (Solaris) version = HAVE_ICONV;
    version ( NetBSD) version = HAVE_ICONV;
    debug (USE_LIBICONV) version = HAVE_ICONV;
}
else
{
    enum backingTranscoder = Transcoder.none;
}


//----------------------------------------------------------------------------//
// native codeset detection
//----------------------------------------------------------------------------//

version (Windows)
{
    // The 'ANSI' codepage at program startup.
    immutable DWORD nativeCodepage;

    shared static this()
    {
        .nativeCodepage = GetACP();
    }
}
else version (Posix)
{
    // The default CODESET langinfo at program startup.
    immutable string nativeCodeset;

    // True if the native codeset is UTF-8.
    @safe @property pure nothrow bool isNativeUTF8()
    {
        return .nativeCodeset == "UTF-8";
    }

    shared static this()
    {
        immutable(char)[] origCtype;

        if (auto ctype = setlocale(LC_CTYPE, null))
            origCtype = dupCstringz(ctype);
        else
            origCtype = "C\0";

        setlocale(LC_CTYPE, "");
        scope(exit) setlocale(LC_CTYPE, origCtype.ptr);

        if (auto codeset = nl_langinfo(CODESET))
            .nativeCodeset = to!string(codeset);
        else
            .nativeCodeset = "US-ASCII";
    }

    // duplicate a string including the terminating zero
    private @trusted immutable(char)[] dupCstringz(in char* cstr)
    {
        size_t n = 0;
        while (cstr[n++] != 0) continue;
        return cstr[0 .. n].idup;
    }
}
else
{
    // Dunno how to detect the native codeset.
    enum bool isNativeUTF8  = false;
}


// Detect GNU iconv as its behavior slightly differs from the POSIX standard
static if (.backingTranscoder == Transcoder.iconv)
{
    immutable bool isIconvGNU;      // true <= iconv by GNU

    shared static this()
    {
        iconv_t cd = iconv_open("ASCII//IGNORE", "");

        if (cd != cast(iconv_t) -1)
        {
            .isIconvGNU = true; // maybe
            iconv_close(cd);
        }
    }
}


//----------------------------------------------------------------------------//

class EncodingException : Exception
{
    this(string msg, string file, uint line)
    {
        super(msg, file, line);
    }
}


/*
 * Status code returned by converters.
 */
enum ConvertionStatus
{
    ok,         // convertion succeeded
    empty,      // empty source
}


/*
 * Configuration for converters.
 */
enum ConvertionMode
{
    native,     // use environment native codeset
    console,    // use console native codeset
}


//----------------------------------------------------------------------------//
// NativeCodesetDecoder
//----------------------------------------------------------------------------//

/*
 * Converter from native codeset characters to Unicode code points.
 */
@system struct NativeCodesetDecoder
{
    /*
     * Params:
     *  mode = $(D ConvertionMode) for determining the target codeset.  This
     *    parameter is used only on Windows to distinguish native code page and
     *    console code page; it's just ignored on other platforms.
     *
     * Throws:
     *  $(D EncodingException) if convertion is not supported.
     */
    this(ConvertionMode mode)
    {
        static if (.backingTranscoder == Transcoder.WinNLS)
        {
            DWORD codepage;

            final switch (mode)
            {
              case ConvertionMode.native : codepage = .nativeCodepage; break;
              case ConvertionMode.console: codepage =  GetConsoleCP(); break;
            }
            decoder_ = WindowsNativeCodesetDecoder(codepage);
        }
        else
        {
            if (.isNativeUTF8)
            {
                // We can use our own decoder implementation.
                decoder_ = UTF8Decoder();
                return;
            }

            static if (.backingTranscoder == Transcoder.iconv)
                decoder_ = IconvNativeCodesetDecoder(.nativeCodeset);
            else
                throw new EncodingException("Convertion between native codeset "
                        ~"and Unicode is not supported", __FILE__, __LINE__);
        }
    }


    /+@safe nothrow+/ void opAssign(typeof(this) rhs)
    {
        swap(this, rhs);
    }


    /*
     * Converts a native character at the beginning of $(D source) into the
     * corresponding Unicode code point(s) in $(D sink).
     *
     * Params:
     *  source = input stream offering ubytes.
     *  sink   = output range that accepts dchars.
     *
     * Returns:
     *  $(D ConvertionStatus.ok) if a character is converted to one or more
     *  Unicode code points in $(D sink), or $(D ConvertionStatus.empty) is
     *  returned if $(D source) is empty and nothing is done.
     *
     * Throws:
     *  - $(D EncodingException) if a beginning sequence in $(D source) does
     *    not form a valid native multibyte character.
     */
    ConvertionStatus convertCharacter(Source, Sink)(ref Source source, ref Sink sink)
            if (isOutputRange!(Sink, dchar))
    {
        return decoder_.convertCharacter(source, sink);
    }


    //----------------------------------------------------------------//
private:
    static if (.backingTranscoder == Transcoder.WinNLS)
    {
        WindowsNativeCodesetDecoder decoder_;
    }
    else static if (.backingTranscoder == Transcoder.iconv)
    {
        Algebraic!(UTF8Decoder, IconvNativeCodesetDecoder) decoder_;
    }
    else
    {
        UTF8Decoder decoder_;
    }
}

unittest
{
    NativeCodesetDecoder decoder;

    try
    {
        decoder = NativeCodesetDecoder(ConvertionMode.native);
        decoder = NativeCodesetDecoder(ConvertionMode.console);
    }
    catch (EncodingException e)
    {
        // Not supported
        return;
    }

    ubyte[] src;
    dchar[] dst;
    auto stat = decoder.convertCharacter(src, dst);
    assert(stat == ConvertionStatus.empty);
}


/*
 * Converts UTF-8 sequence to the corresponding Unicode code point.
 */
private @system struct UTF8Decoder
{
static: // stateless

    /*
     * Converts a UTF-8 encoded code point at the beginning of $(D source)
     * into the code point in $(D sink).
     *
     * Throws:
     *  - $(D EncodingException) on invalid or incomplete UTF-8 sequence.
     */
    ConvertionStatus convertCharacter(Source, Sink)(ref Source source, ref Sink sink)
            if (isOutputRange!(Sink, dchar))
    {
        ubyte u1;

        if (!readNext(source, u1))
            return ConvertionStatus.empty;

        if (u1 < 0x80)
        {
            sink.put(cast(dchar) u1);
            return ConvertionStatus.ok;
        }

        // Decode trailing byte sequence...
        dchar  code;
        dchar  boundary;
        size_t stride;

        final switch (u1 >> 4)
        {
          case 0b1100, 0b1101:
            code     = u1 & 0b0001_1111;
            stride   = 2;
            boundary = '\u0080';
            break;

          case 0b1110:
            code     = u1 & 0b0000_1111;
            stride   = 3;
            boundary = '\u0800';
            break;

          case 0b1111:
            if (u1 & 0b0000_1000)
                throw new EncodingException("invalid UTF-8 leading byte", __FILE__, __LINE__);
            code     = u1 & 0b0000_0111;
            stride   = 4;
            boundary = '\U00010000';
            break;

          case 0b1000, 0b1001, 0b1010, 0b1011:
            throw new EncodingException("sudden UTF-8 trailing byte", __FILE__, __LINE__);
        }
        assert(stride >= 2);

        foreach (i; 1 .. stride)
        {
            ubyte u;

            if (!readNext(source, u) || (u & 0b11000000) != 0b10000000)
                throw new EncodingException("error in UTF-8 trailing sequence", __FILE__, __LINE__);
            code = (code << 6) | (u & 0b00111111);
        }

        // Check for invalid code point and overlong sequence.
        if (!isValidDchar(code) || code < boundary)
            throw new EncodingException("invalid code point", __FILE__, __LINE__);

        sink.put(code);
        return ConvertionStatus.ok;
    }
}

unittest
{
    // Accepts ubyte
    ubyte[] src;
    dchar[] dst;
    auto decoder = UTF8Decoder();
    auto stat = decoder.convertCharacter(src, dst);
    assert(stat == ConvertionStatus.empty);
}

unittest
{
    // Converts valid code points
    enum codepoints =
         "\u0000\u007F\u0080\u07FF\u0800\uD7FF\uE000\uFFFD"
        ~"\U00010000\U0001D800\U0001DBFF\U0001DC00\U0001DFFF\U0001FFFF"
        ~"\U000F0000\U000FD800\U000FDBFF\U000FDC00\U000FDFFF\U000FFFFF"
        ~"\U00100000\U0010D800\U0010DBFF\U0010DC00\U0010DFFF\U0010FFFF";
    dstring witness = codepoints;
    string  src     = codepoints;
    dchar[] store   = new dchar[](32);
    dchar[] dst     = store;

    auto decoder = UTF8Decoder();

    while (decoder.convertCharacter(src, dst) == ConvertionStatus.ok)
        continue;
    auto stat = decoder.convertCharacter(src, dst);
    assert(stat == ConvertionStatus.empty);

    assert(src.empty);
    assert(dst.length == 6);
    assert(store[0 .. $ - dst.length] == witness);
}

unittest
{
    // Throws on invalid sequence
    string[] wrongList =
    [
        "\xE3",
        "\xE3\x81",
        "\xFE\xFF",
        "\xFF\xFE",

        "\xED\xA0\x80",
        "\xED\xAD\xBF",
        "\xED\xAE\x80",
        "\xED\xAF\xBF",
        "\xED\xB0\x80",
        "\xED\xBE\x80",
        "\xED\xBF\xBF",

        "\xF4\x90\x80\x80"
        "\xF8\x88\x80\x80\x80",
        "\xFC\x88\x80\x80\x80\x80",

        "\xC0\x80",
        "\xC1\xBF",
        "\xE0\x80\x80",
        "\xE0\x9F\xBF",
        "\xF0\x80\x80\x80",
        "\xF0\x8F\xBF\xBF"
    ];
    foreach (i, wrong; wrongList)
    {
        auto decoder = UTF8Decoder();
        try
        {
            dchar[] dst = new dchar[](4);
            decoder.convertCharacter(wrong, dst);
            assert(0, "#" ~ to!string(i));
        }
        catch (EncodingException e)
        {
        }
    }
}


/*
 * Converts native multibyte character sequence to the corresponding Unicode
 * code point(s) with MultiByteToWideChar.
 *
 * This implementation can't handle stateful encodings (e.g. ISO-2022) nor
 * longer multibyte encodings (e.g. GB18030, single shift 3-byte EUC-JP).
 */
version (Windows)
private @system struct WindowsNativeCodesetDecoder
{
    static assert(is(WCHAR == wchar));

    this(DWORD codepage)
    in
    {
        assert(IsValidCodePage(codepage));
    }
    body
    {
        codepage_ = codepage;
    }


    /*
     * Converts a native character sequence at the beginning of $(D source)
     * into the corresponding UTF-32 sequence in $(D sink).
     *
     * Throws:
     *  - $(D EncodingException) on invalid multibyte sequence.
     *  - $(D EncodingException) on incomplete multibyte sequence.
     *  - $(D Exception) on unexpected Windows API error.
     */
    ConvertionStatus convertCharacter(Source, Sink)(ref Source source, ref Sink sink)
            if (isOutputRange!(Sink, dchar))
    {
        // double-byte character sequence read from the source
        ubyte[2] mbcseq     = void;
        size_t   mbcseqRead = 0;

        if (readNext(source, mbcseq[0]))
            ++mbcseqRead;
        else
            return ConvertionStatus.empty;

        if (IsDBCSLeadByteEx(codepage_, mbcseq[0]))
        {
            if (readNext(source, mbcseq[mbcseqRead]))
                ++mbcseqRead;
            else
                throw new EncodingException("missing trailing multibyte sequence",
                        __FILE__, __LINE__);
        }

        // UTF-16 sequence corresponding to the input
        wchar[8] wcharsStack = void;
        wchar[]  wchars      = wcharsStack;

        while (true)
        {
            int wcLen;

            wcLen = MultiByteToWideChar(codepage_, 0,
                    cast(LPCSTR) mbcseq.ptr, mbcseqRead, wchars.ptr, wchars.length);
            if (wcLen <= 0)
            {
                switch (GetLastError())
                {
                  case ERROR_INVALID_PARAMETER:
                    throw new EncodingException("input string contains invalid "
                            ~"byte sequence in the native codeset", __FILE__, __LINE__);

                  case ERROR_INSUFFICIENT_BUFFER:
                    // The stack-allocated buffer was insufficient. Let's allocate
                    // a sufficient buffer on the GC heap and retry.
                    wcLen = MultiByteToWideChar(codepage_, 0,
                            cast(LPCSTR) mbcseq.ptr, mbcseqRead, null, 0);
                    if (wcLen <= 0)
                        goto default;
                    wchars = new wchar[](wcLen);
                    continue;

                  default:
                    throw new Exception(sysErrorString(GetLastError()), __FILE__, __LINE__);
                }
                assert(0);
            }

            wchars = wchars[0 .. wcLen];
            break;
        }
        assert(wchars.length > 0);

        // Write the corresponding UTF-32 sequence to the sink.
        for (size_t i = 0; i < wchars.length; )
            sink.put(wchars.decode(i));

        return ConvertionStatus.ok;
    }


    //----------------------------------------------------------------//
private:
    DWORD codepage_;        // native codepage
}

version (Windows) unittest
{
    auto decoder = WindowsNativeCodesetDecoder(437);

    ubyte[] src;
    dchar[] dst;

    auto stat = decoder.convertCharacter(src, dst);
    assert(stat == ConvertionStatus.empty);
    assert(src.empty);
    assert(dst.empty);
}

version (Windows) unittest
{
    // Windows-1252
    auto decoder = WindowsNativeCodesetDecoder(1252);

    dstring witness =
         "\u20ac\u201a\u0192\u201e\u2026\u2020\u2021\u02c6\u2030\u0160\u2039\u0152\u017d"
        ~"\u2018\u2019\u201c\u201d\u2022\u2013\u2014\u02dc\u2122\u0161\u203a\u0153\u017e\u0178";
    ubyte[] input =
        [ 0x80,0x82,0x83,0x84,0x85,0x86,0x87,0x88,0x89,0x8a,0x8b,0x8c,0x8e,
          0x91,0x92,0x93,0x94,0x95,0x96,0x97,0x98,0x99,0x9a,0x9b,0x9c,0x9e,0x9f ];
    assert(witness.length == input.length);

    foreach (i, u; input)
    {
        dchar[2] store;
        dchar[]  dst = store;
        ubyte[]  src = [ u ];

        assert(src.length == 1);
        assert(dst.length == 2);

        auto stat1 = decoder.convertCharacter(src, dst);
        assert(stat1 == ConvertionStatus.ok);
        assert(src.length == 0);
        assert(dst.length == 1);

        auto stat2 = decoder.convertCharacter(src, dst);
        assert(stat2 == ConvertionStatus.empty);
        assert(src.length == 0);
        assert(dst.length == 1);

        assert(store[0] == witness[i]);
    }
}

version (Windows) unittest
{
    // Big-5 variant
    auto decoder = WindowsNativeCodesetDecoder(950);

    dstring witness = "\u0000\u007f\u3000\u20ac\u4e00\u5afa\u2554\u2593";
    dchar[] store   = new dchar[](10);

    ubyte[] src = [ 0x00,0x7f,0xa1,0x40,0xa3,0xe1,0xa4,0x40,0xf9,0xdc,0xf9,0xdd,0xf9,0xfe ];
    ubyte[] wid = [    1,   1,        2,        2,        2,        2,        2,        2 ];
    dchar[] dst = store;

    assert(src.length == 14);
    assert(wid.length ==  8);
    assert(dst.length == 10);

    for (size_t k = 0, i = 0; i < wid.length; )
    {
        k += wid[i++];
        auto stat = decoder.convertCharacter(src, dst);
        assert(stat == ConvertionStatus.ok);
        assert(src.length == 14 - k);
        assert(dst.length == 10 - i);
    }
    assert(src.length == 0);
    assert(dst.length == 2);

    auto stat = decoder.convertCharacter(src, dst);
    assert(stat == ConvertionStatus.empty);
    assert(src.length == 0);
    assert(dst.length == 2);

    assert(store[0 .. $ - dst.length] == witness);
    assert(store[$ - dst.length] == dchar.init);
}

version (Windows) unittest
{
    // Shift_JIS variant
    auto decoder = WindowsNativeCodesetDecoder(932);

    dstring witness = "\u0000\u007f\u3000\u222a\u4e9c\u9ed1\uff61\uff9f";
    dchar[] store   = new dchar[](10);

    ubyte[] src = [ 0x00,0x7f,0x81,0x40,0x87,0x9c,0x88,0x9f,0xfc,0x4b,0xa1,0xdf ];
    ubyte[] wid = [    1,   1,        2,        2,        2,        2,   1,   1 ];
    dchar[] dst = store;

    assert(src.length == 12);
    assert(wid.length ==  8);
    assert(dst.length == 10);

    for (size_t k = 0, i = 0; i < wid.length; )
    {
        k += wid[i++];
        auto stat = decoder.convertCharacter(src, dst);
        assert(stat == ConvertionStatus.ok);
        assert(src.length == 12 - k);
        assert(dst.length == 10 - i);
    }
    assert(src.length == 0);
    assert(dst.length == 2);

    auto stat = decoder.convertCharacter(src, dst);
    assert(stat == ConvertionStatus.empty);
    assert(src.length == 0);
    assert(dst.length == 2);

    assert(store[0 .. $ - dst.length] == witness);
    assert(store[$ - dst.length] == dchar.init);
}


/*
 * Converts native multibyte character sequence to the corresponding Unicode
 * code point(s) with POSIX iconv.
 */
version (HAVE_ICONV)
private @system struct IconvNativeCodesetDecoder
{
    this(string codeset)
    {
        // We specify UTF-8 for tocode because some iconv implementations
        // (e.g. Solaris) do not support convertion between certain codesets
        // and UTF-32, whereas UTF-8 is supported.

        copyCount_ = new int;
        decoder_   = iconv_open("UTF-8", codeset.toStringz());
        errnoEnforce(decoder_ != cast(iconv_t) -1);
    }

    this(this)
    {
        if (copyCount_)
            ++*copyCount_;
    }

    ~this()
    {
        if (copyCount_ && (*copyCount_)-- == 0)
            errnoEnforce(iconv_close(decoder_) != -1);
    }


    /*
     * Converts a native character sequence at the beginning of $(D source)
     * into the corresponding UTF-32 sequence in $(D sink).
     *
     * Throws:
     *  - $(D EncodingException) on invalid multibyte sequence.
     *  - $(D EncodingException) on incomplete multibyte sequence.
     *  - $(D ErrnoException) on unexpected iconv error.
     */
    ConvertionStatus convertCharacter(Source, Sink)(ref Source source, ref Sink sink)
            if (isOutputRange!(Sink, dchar))
    {
        // multibyte character sequence read from the source
        ubyte[16] mbcseqStack = void;
        ubyte[]   mbcseq      = mbcseqStack;
        size_t    mbcseqRead  = 0;  // # of bytes read from the source
        size_t    mbcseqUsed  = 0;  // # of bytes converted

        if (readNext(source, mbcseq[0]))
            ++mbcseqRead;
        else
            return ConvertionStatus.empty;

        // UTF-8 sequence corresponding to the input
        char[16] ucharsStack = void;
        char[]   uchars      = ucharsStack;
        size_t   ucharsUsed  = 0;   // # of code units stored in uchars[]

        // Start converting a multibyte character.
        do
        {
            assert(mbcseqUsed < mbcseq.length);
            assert(ucharsUsed < uchars.length);

            ubyte* src     = &mbcseq[mbcseqUsed];
            size_t srcLeft = mbcseqRead - mbcseqUsed;
            ubyte* dst     = cast(ubyte*) &uchars[ucharsUsed];
            size_t dstLeft = uchars.length - ucharsUsed;

            immutable rc = iconv(decoder_, &src, &srcLeft, &dst, &dstLeft);

            mbcseqUsed += mbcseqRead    - srcLeft;
            ucharsUsed += uchars.length - dstLeft;

            if (rc == cast(size_t) -1)
            {
                switch (errno)
                {
                  case EINVAL:
                    // Incomplete multibyte sequence. Read more byte and retry.
                    if (mbcseq.length == mbcseqRead)
                        mbcseq.length *= 2;

                    if (readNext(source, mbcseq[mbcseqRead]))
                        ++mbcseqRead;
                    else
                        throw new EncodingException("missing trailing multibyte sequence",
                                __FILE__, __LINE__);
                    continue;

                  case EILSEQ:
                    throw new EncodingException("input string contains invalid "
                            ~"byte sequence in the native codeset", __FILE__, __LINE__);

                  case E2BIG:
                    // The output buffer was insufficient. Let's expand it on
                    // the GC heap and retry.
                    uchars.length *= 2;
                    continue;

                  default:
                    throw new ErrnoException("converting a native coded "
                        "character to the corresponding Unicode code point");
                }
                assert(0);
            }
        }
        while (mbcseqUsed < mbcseqRead);

        assert(mbcseqUsed == mbcseqRead);
        assert(ucharsUsed > 0);

        uchars = uchars[0 .. ucharsUsed];

        // Write the resulting UTF-32 sequence to the sink.
        for (size_t i = 0; i < uchars.length; )
            sink.put(uchars.decode(i));

        return ConvertionStatus.ok;
    }


    //----------------------------------------------------------------//
private:
    iconv_t decoder_;       // native => UTF-32
    int*    copyCount_;     // for managing iconv_t resource
}

version (HAVE_ICONV) unittest
{
    dchar[4] store;

    dstring wit = "\u65e5\u672c\u8a9e";
    ubyte[] src = [ 0xc6,0xfc,0xcb,0xdc,0xb8,0xec ];
    dchar[] dst = store;

    auto decoder = IconvNativeCodesetDecoder("EUC-JP");
    assert(src.length == 6);
    assert(dst.length == 4);

    auto stat1 = decoder.convertCharacter(src, dst);
    assert(stat1 == ConvertionStatus.ok);
    assert(src.length == 4);
    assert(dst.length == 3);

    auto stat2 = decoder.convertCharacter(src, dst);
    assert(stat2 == ConvertionStatus.ok);
    assert(src.length == 2);
    assert(dst.length == 2);

    auto stat3 = decoder.convertCharacter(src, dst);
    assert(stat3 == ConvertionStatus.ok);
    assert(src.length == 0);
    assert(dst.length == 1);

    auto stat4 = decoder.convertCharacter(src, dst);
    assert(stat4 == ConvertionStatus.empty);
    assert(src.length == 0);
    assert(dst.length == 1);

    assert(store[0 .. 3] == wit[]);
    assert(store[3] == dchar.init);
}

version (HAVE_ICONV) unittest
{
    dchar[10] store;

    dstring wit = "\u0000\u0019\u0020\u007f\u0080\u009f\u00a0\u00ff";
    ubyte[] src = [ 0x00,0x19,0x20,0x7f,0x80,0x9f,0xa0,0xff ];
    dchar[] dst = store;

    auto decoder = IconvNativeCodesetDecoder("ISO-8859-1");
    assert(src.length == 8);
    assert(dst.length == 10);

    foreach (i; 0 .. 8)
    {
        auto stat = decoder.convertCharacter(src, dst);
        assert(stat == ConvertionStatus.ok);
        assert(src.length == 7 - i);
        assert(dst.length == 9 - i);
    }
    assert(src.length == 0);
    assert(dst.length == 2);

    auto stat = decoder.convertCharacter(src, dst);
    assert(stat == ConvertionStatus.empty);
    assert(src.length == 0);
    assert(dst.length == 2);

    assert(store[0 .. 8] == wit[]);
    assert(store[8] == dchar.init);
}


//----------------------------------------------------------------------------//
// NativeCodesetEncoder
//----------------------------------------------------------------------------//

/*
 * For converting UTF string of type $(D string), $(D wstring) or $(D dstring)
 * into the corresponding native multibyte character sequence.
 */
@system struct NativeCodesetEncoder
{
    /*
     * Params:
     *  mode = $(D ConvertionMode) for determining the target codeset.  This
     *    parameter is used only on Windows to distinguish native code page and
     *    console code page; it's just ignored on other platforms.
     *
     * Throws:
     *  - $(D EncodingException) if convertion is not supported.
     */
    this(ConvertionMode mode)
    {
        static if (.backingTranscoder == Transcoder.WinNLS)
        {
            DWORD codepage;

            final switch (mode)
            {
              case ConvertionMode.native : codepage =      .nativeCodepage; break;
              case ConvertionMode.console: codepage = GetConsoleOutputCP(); break;
            }
            encoder_ = chainConverters(
                    UTFTextConverter!wchar(),
                    WindowsNativeCodesetEncoder(codepage));
        }
        else
        {
            if (.isNativeUTF8)
            {
                // We can use our own encoder implementation.
                encoder_ = chainConverters(
                        UTFTextConverter!char(),
                        CastingConverter!ubyte());
                return;
            }

            static if (.backingTranscoder == Transcoder.iconv)
                encoder_ = chainConverters(
                        UTFTextConverter!char(),
                        IconvNativeCodesetEncoder(.nativeCodeset));
            else
                throw new EncodingException("Convertion between native codeset "
                        ~"and Unicode is not supported", __FILE__, __LINE__);
        }
    }


    /+@safe nothrow+/ void opAssign(typeof(this) rhs)
    {
        swap(this, rhs);
    }


    /*
     * Converts entire UTF text $(D chunk) into the corresponding native multibyte
     * character sequence in $(D sink).
     *
     * Params:
     *  chunk = valid UTF string to convert.
     *  sink  = output range that accepts ubyte[]s.
     *
     * Returns:
     *  $(D ConvertionStatus.ok) if at least one character is converterd and
     *  written to $(D sink), or $(D ConvertionStatus.empty) is returned if
     *  $(D chunk) is empty and nothing is done.
     *
     * Throws:
     *  $(D EncodingException) if $(D chunk) contains ill formed UTF sequence.
     *
     * Note:
     *  Some characters in $(D chunk) may not be representable in the native
     *  codeset.  Such characters would be replaced with a default replacement
     *  character offered by the system, or just dropped.
     */
    ConvertionStatus convertChunk(Chunk, Sink)(Chunk chunk, ref Sink sink)
            if (isSomeString!(Chunk) && isOutputRange!(Sink, ubyte[]))
    {
        return encoder_.convertChunk(chunk, sink);
    }


    //----------------------------------------------------------------//
private:
    static if (.backingTranscoder == Transcoder.WinNLS)
    {
        ConverterChain!(UTFTextConverter!wchar, WindowsNativeCodesetEncoder)
                encoder_;
    }
    else static if (.backingTranscoder == Transcoder.iconv)
    {
        Algebraic!(
            ConverterChain!(UTFTextConverter!char,    CastingConverter!ubyte),
            ConverterChain!(UTFTextConverter!char, IconvNativeCodesetEncoder))
                encoder_;
    }
    else
    {
        ConverterChain!(UTFTextConverter!char, CastingConverter!ubyte)
                encoder_;
    }
}

unittest
{
    NativeCodesetEncoder encoder;

    try
    {
        encoder = NativeCodesetEncoder(ConvertionMode.native);
        encoder = NativeCodesetEncoder(ConvertionMode.console);
    }
    catch (EncodingException e)
    {
        // not supported
        return;
    }

    ConvertionStatus stat;
    auto sink = NaiveCatenator!ubyte();

    stat = encoder.convertChunk(""c, sink);
    assert(stat == ConvertionStatus.empty);

    stat = encoder.convertChunk(""w, sink);
    assert(stat == ConvertionStatus.empty);

    stat = encoder.convertChunk(""d, sink);
    assert(stat == ConvertionStatus.empty);
}


/*
 * Converts WCHARs (UTF-16 sequence) to the corresponding multibyte character
 * sequence with WideCharToMultiByte.
 *
 * This implementation can't handle stateful encodings (e.g. ISO-2022).
 */
version (Windows)
private @system struct WindowsNativeCodesetEncoder
{
    this(DWORD codepage)
    in
    {
        assert(isValidDchar(codepage));
    }
    body
    {
        codepage_ = codepage;
    }


    /*
     * Converts entire UTF-16 text $(D chunk) into the corresponding native multibyte
     * character sequence in $(D sink).
     *
     * Params:
     *  chunk = valid UTF-16 string to convert.
     *  sink  = output range that accepts multibyte characters of type $(D ubyte[]).
     *
     * Throws:
     *  - $(D EncodingException) if the converted string $(D chunk) contains invalid
     *    UTF-16 sequence.
     *  - $(D Exception) on unexpected Windows API failure.
     */
    ConvertionStatus convertChunk(Sink)(in wchar[] chunk, ref Sink sink)
            if (isOutputRange!(Sink, ubyte[]))
    {
        if (chunk.length == 0)
            return ConvertionStatus.empty;

        ubyte[128] mbstrStack = void;
        ubyte[]    mbstr      = mbstrStack;
        int        mbstrLen;    // size of the multibyte string

        mbstrLen = WideCharToMultiByte(codepage_, 0,
                chunk.ptr, chunk.length, null, 0, null, null);
        if (mbstrLen <= 0)
        {
            switch (GetLastError())
            {
              case ERROR_INVALID_PARAMETER:
                throw new EncodingException("invalid UTF sequence in the input string",
                        __FILE__, __LINE__);

              default:
                throw new Exception(sysErrorString(GetLastError()), __FILE__, __LINE__);
            }
            assert(0);
        }

        if (mbstr.length < mbstrLen)
            mbstr = new ubyte[](mbstrLen);

        mbstrLen = WideCharToMultiByte(codepage_, 0,
                chunk.ptr, chunk.length, cast(LPSTR) mbstr.ptr, mbstr.length, null, null);
        enforce(mbstrLen > 0, sysErrorString(GetLastError()));

        sink.put(mbstr[0 .. mbstrLen]);
        return ConvertionStatus.ok;
    }


    //----------------------------------------------------------------//
private:
    DWORD codepage_;        // native codepage
}

version (Windows) unittest
{
    auto encoder = WindowsNativeCodesetEncoder(1252);

    wchar[] src;
    auto sink  = NaiveCatenator!ubyte();
    auto stat = encoder.convertChunk(src, sink);
    assert(stat == ConvertionStatus.empty);
}

version (Windows) unittest
{
    wstring input =
         "\u20ac\u201a\u0192\u201e\u2026\u2020\u2021\u02c6\u2030\u0160\u2039\u0152\u017d"
        ~"\u2018\u2019\u201c\u201d\u2022\u2013\u2014\u02dc\u2122\u0161\u203a\u0153\u017e\u0178";
    ubyte[] witness =
        [ 0x80,0x82,0x83,0x84,0x85,0x86,0x87,0x88,0x89,0x8a,0x8b,0x8c,0x8e,
          0x91,0x92,0x93,0x94,0x95,0x96,0x97,0x98,0x99,0x9a,0x9b,0x9c,0x9e,0x9f ];

    auto encoder = WindowsNativeCodesetEncoder(1252);
    auto sink     = NaiveCatenator!ubyte();

    auto stat1 = encoder.convertChunk(input[0 .. 13], sink);
    assert(stat1 == ConvertionStatus.ok);
    assert(sink.data.length == 13);

    auto stat2 = encoder.convertChunk(input[13 .. 26], sink);
    assert(stat2 == ConvertionStatus.ok);
    assert(sink.data.length == 26);

    auto stat3 = encoder.convertChunk(input[26 .. 27], sink);
    assert(stat3 == ConvertionStatus.ok);
    assert(sink.data.length == 27);

    auto stat4 = encoder.convertChunk(input[27 .. 27], sink);
    assert(stat4 == ConvertionStatus.empty);
    assert(sink.data.length == 27);

    assert(sink.data == witness);
}

version (Windows) unittest
{
    wstring input = "\u002e\u7af9\u85ea\u3084\u3051\u305f\u002e";
    ubyte[] witness = [ 0x2e,0x92,0x7c,0xe5,0x4d,0x82,0xe2,0x82,0xaf,0x82,0xbd,0x2e ];

    auto encoder = WindowsNativeCodesetEncoder(932);
    auto sink     = NaiveCatenator!ubyte();

    auto stat1 = encoder.convertChunk(input[0 .. 4], sink);
    assert(stat1 == ConvertionStatus.ok);
    assert(sink.data.length == 7);

    auto stat2 = encoder.convertChunk(input[4 .. 6], sink);
    assert(stat2 == ConvertionStatus.ok);
    assert(sink.data.length == 11);

    auto stat3 = encoder.convertChunk(input[6 .. 7], sink);
    assert(stat3 == ConvertionStatus.ok);
    assert(sink.data.length == 12);

    auto stat4 = encoder.convertChunk(input[7 .. 7], sink);
    assert(stat4 == ConvertionStatus.empty);
    assert(sink.data.length == 12);

    assert(sink.data == witness);
}


/*
 * Converts dchars (UTF-32 sequence) to the corresponding multibyte character
 * sequence with POSIX iconv.
 */
version (HAVE_ICONV)
private @system struct IconvNativeCodesetEncoder
{
    this(string codeset)
    {
        if (.isIconvGNU) codeset ~= "//IGNORE";   // for POSIX compat.

        // We specify UTF-8 for from because some iconv implementations
        // (e.g. Solaris) do not support convertion between certain codesets
        // and UTF-32, whereas UTF-8 is supported.

        copyCount_ = new int;
        encoder_   = iconv_open(codeset.toStringz(), "UTF-8");
        errnoEnforce(encoder_ != cast(iconv_t) -1);
    }

    @trusted this(this)
    {
        if (copyCount_)
            ++*copyCount_;
    }

    ~this()
    {
        if (copyCount_ && (*copyCount_)-- == 0)
            errnoEnforce(iconv_close(encoder_) != -1);
    }


    /*
     * Converts entire UTF-8 string $(D chunk) into the corresponding native
     * character sequence in $(D sink).
     *
     * Params:
     *  chunk = valid UTF-8 string to convert.
     *  sink  = output range that accepts multibyte characters of type $(D ubyte[]).
     *
     * Throws:
     *  - $(D EncodingException) if $(D chunk) contains invalid UTF-8 sequence.
     *  - $(D ErrnoExceptino) on unexpected iconv failure.
     */
    ConvertionStatus convertChunk(Sink)(in char[] chunk, ref Sink sink)
            if (isOutputRange!(Sink, ubyte[]))
    {
        if (chunk.length == 0)
            return ConvertionStatus.empty;

        ubyte[128] mcharsStack = void;
        ubyte[]    mchars      = mcharsStack;

        auto src     = cast(const(ubyte)*) chunk.ptr;
        auto srcLeft = chunk.length;

        while (srcLeft > 0)
        {
            ubyte* dst     = mchars.ptr;
            size_t dstLeft = mchars.length;

            immutable size_t rc = iconv(encoder_, &src, &srcLeft, &dst, &dstLeft);
            immutable int iconvErrno = errno;

            // Output successfully converted characters (available even on error).
            if (dstLeft < mchars.length)
                sink.put(mchars[0 .. $ - dstLeft]);

            if (rc == cast(size_t) -1)
            {
                switch (errno = iconvErrno)
                {
                  case EILSEQ:
                    // [workaround] GNU iconv raises EILSEQ on mapping failure
                    if (.isIconvGNU)
                    {
                        size_t k = 0;
                        decode((cast(char*) src)[0 .. srcLeft], k);
                            // This throws if it was actually illegal.
                        src     += k;
                        srcLeft -= k;
                        continue;
                    }
                    throw new EncodingException("invalid Unicode code point in "
                            ~"the input string", __FILE__, __LINE__);

                  case E2BIG:
                    mchars.length *= 2;
                    continue;

                  default:
                    throw new ErrnoException("iconv");
                }
            }
        }
        return ConvertionStatus.ok;
    }


    //----------------------------------------------------------------//
private:
    iconv_t encoder_;       // UTF-32 => native
    int*    copyCount_;     // for managing iconv_t resource
}

version (HAVE_ICONV) unittest
{
    auto encoder = IconvNativeCodesetEncoder(.nativeCodeset);

    char[] src;
    auto sink = NaiveCatenator!ubyte();
    auto stat = encoder.convertChunk(src, sink);
    assert(stat == ConvertionStatus.empty);
}

version (HAVE_ICONV) unittest
{
    auto encoder = IconvNativeCodesetEncoder("ISO-8859-1");

    string  src = "\u0000\u001f\u0020\u007f\u0080\u009f\u00a0\u00ff";
    ubyte[] wit = [ 0x00,0x1f,0x20,0x7f,0x80,0x9f,0xa0,0xff ];
    auto    sink = NaiveCatenator!ubyte();

    assert(sink.data.empty);

    auto stat = encoder.convertChunk(src, sink);
    assert(stat == ConvertionStatus.ok);
    assert(sink.data == wit);
}

version (HAVE_ICONV) unittest
{
    auto encoder = IconvNativeCodesetEncoder("Shift_JIS");

    string  src = "\u002e\u7af9\u85ea\u3084\u3051\u305f\u002e";
    ubyte[] wit = [ 0x2e,0x92,0x7c,0xe5,0x4d,0x82,0xe2,0x82,0xaf,0x82,0xbd,0x2e ];
    auto    sink = NaiveCatenator!ubyte();

    assert(sink.data.empty);

    auto stat = encoder.convertChunk(src, sink);
    assert(stat == ConvertionStatus.ok);
    assert(sink.data == wit);
}


//----------------------------------------------------------------------------//
// UTF-x Converters
//----------------------------------------------------------------------------//

/*
 * Struct for converting text (string, wstring and dstring) into char[].
 * Used for IconvNativeCodesetEncoder to normalize input text to string.
 */
private struct UTFTextConverter(Unit : char)
{
static:
    private enum size_t BUFFER_SIZE = 128;

    ConvertionStatus convertChunk(Sink)(in char[] chunk, ref Sink sink)
            if (isOutputRange!(Sink, char[]))
    {
        if (chunk.empty)
            return ConvertionStatus.empty;
        else
            return sink.put(chunk), ConvertionStatus.ok;
    }

    ConvertionStatus convertChunk(Sink)(in wchar[] chunk, ref Sink sink)
            if (isOutputRange!(Sink, char[]))
    {
        if (chunk.empty)
            return ConvertionStatus.empty;
        //
        char[BUFFER_SIZE] ustore = void;
        char[]            ubuf   = ustore;

        for (size_t i = 0; i < chunk.length; )
        {
            assert(ubuf.length >= 4);
            putUTF!char(ubuf, chunk.decode(i));

            if (ubuf.length < 4 || i == chunk.length)
            {
                sink.put(ustore[0 .. $ - ubuf.length]);
                ubuf = ustore;
            }
        }
        return ConvertionStatus.ok;
    }

    ConvertionStatus convertChunk(Sink)(in dchar[] chunk, ref Sink sink)
            if (isOutputRange!(Sink, char[]))
    {
        if (chunk.empty)
            return ConvertionStatus.empty;
        //
        char[BUFFER_SIZE] ustore = void;
        char[]            ubuf   = ustore;

        for (size_t i = 0; i < chunk.length; )
        {
            assert(ubuf.length >= 4);
            putUTF!char(ubuf, chunk[i++]);

            if (ubuf.length < 4 || i == chunk.length)
            {
                sink.put(ustore[0 .. $ - ubuf.length]);
                ubuf = ustore;
            }
        }
        return ConvertionStatus.ok;
    }
}

unittest
{
    UTFTextConverter!char conv;
    auto sink = NaiveCatenator!char();

    auto stat1 = conv.convertChunk(""c, sink);
    assert(stat1 == ConvertionStatus.empty);
    assert(sink.data.empty);

    auto stat2 = conv.convertChunk(""w, sink);
    assert(stat2 == ConvertionStatus.empty);
    assert(sink.data.empty);

    auto stat3 = conv.convertChunk(""d, sink);
    assert(stat3 == ConvertionStatus.empty);
    assert(sink.data.empty);
}

unittest
{
    UTFTextConverter!char conv;
    auto sink = NaiveCatenator!char();

    auto stat1 = conv.convertChunk("\u0000\u007f\u0080\u07ff"c, sink);
    assert(stat1 == ConvertionStatus.ok);
    assert(!sink.data.empty);

    auto stat2 = conv.convertChunk("\u0800\ud7ff\ue000\ufffd"w, sink);
    assert(stat2 == ConvertionStatus.ok);
    assert(!sink.data.empty);

    auto stat3 = conv.convertChunk("\U00010000\U0001dc00\U0010ffff"d, sink);
    assert(stat3 == ConvertionStatus.ok);
    assert(!sink.data.empty);

    assert(sink.data ==
             "\u0000\u007f\u0080\u07ff\u0800\ud7ff\ue000\ufffd"
            ~"\U00010000\U0001dc00\U0010ffff"c);
}


/*
 * Struct for converting text (string, wstring and dstring) into wchar[].
 * Used for WindowsNativeCodesetEncoder to normalize input string to wstring.
 */
private struct UTFTextConverter(Unit : wchar)
{
static:
    private enum size_t BUFFER_SIZE = 80;

    ConvertionStatus convertChunk(Sink)(in char[] chunk, ref Sink sink)
            if (isOutputRange!(Sink, wchar[]))
    {
        if (chunk.empty)
            return ConvertionStatus.empty;
        //
        wchar[BUFFER_SIZE] wstore = void;
        wchar[]            wbuf   = wstore;

        for (size_t i = 0; i < chunk.length; )
        {
            assert(wbuf.length >= 2);
            putUTF!wchar(wbuf, chunk.decode(i));

            if (wbuf.length < 2 || i == chunk.length)
            {
                sink.put(wstore[0 .. $ - wbuf.length]);
                wbuf = wstore;
            }
        }
        return ConvertionStatus.ok;
    }

    ConvertionStatus convertChunk(Sink)(in wchar[] chunk, ref Sink sink)
            if (isOutputRange!(Sink, wchar[]))
    {
        if (chunk.empty)
            return ConvertionStatus.empty;
        else
            return sink.put(chunk), ConvertionStatus.ok;
    }

    ConvertionStatus convertChunk(Sink)(in dchar[] chunk, ref Sink sink)
            if (isOutputRange!(Sink, wchar[]))
    {
        if (chunk.empty)
            return ConvertionStatus.empty;
        //
        wchar[BUFFER_SIZE] wstore = void;
        wchar[]            wbuf   = wstore;

        for (size_t i = 0; i < chunk.length; )
        {
            assert(wbuf.length >= 2);
            putUTF!wchar(wbuf, chunk[i++]);

            if (wbuf.length < 2 || i == chunk.length)
            {
                sink.put(wstore[0 .. $ - wbuf.length]);
                wbuf = wstore;
            }
        }
        return ConvertionStatus.ok;
    }
}

unittest
{
    UTFTextConverter!wchar conv;
    auto sink = NaiveCatenator!wchar();

    auto stat1 = conv.convertChunk(""c, sink);
    assert(stat1 == ConvertionStatus.empty);
    assert(sink.data.empty);

    auto stat2 = conv.convertChunk(""w, sink);
    assert(stat2 == ConvertionStatus.empty);
    assert(sink.data.empty);

    auto stat3 = conv.convertChunk(""d, sink);
    assert(stat3 == ConvertionStatus.empty);
    assert(sink.data.empty);
}

unittest
{
    UTFTextConverter!wchar conv;
    auto sink = NaiveCatenator!wchar();

    auto stat1 = conv.convertChunk("\u0000\u007f\u0080\u07ff"c, sink);
    assert(stat1 == ConvertionStatus.ok);
    assert(!sink.data.empty);

    auto stat2 = conv.convertChunk("\u0800\ud7ff\ue000\ufffd"w, sink);
    assert(stat2 == ConvertionStatus.ok);
    assert(!sink.data.empty);

    auto stat3 = conv.convertChunk("\U00010000\U0001dc00\U0010ffff"d, sink);
    assert(stat3 == ConvertionStatus.ok);
    assert(!sink.data.empty);

    assert(sink.data ==
             "\u0000\u007f\u0080\u07ff\u0800\ud7ff\ue000\ufffd"
            ~"\U00010000\U0001dc00\U0010ffff"w);
}


//----------------------------------------------------------------------------//
// 
//----------------------------------------------------------------------------//

/*
 * Internally used for casting element type of chunks.
 */
private @system struct CastingConverter(ToE)
{
static:
    ConvertionStatus convertChunk(Chunk, Sink)(Chunk chunk, ref Sink sink)
            if (isOutputRange!(Sink, const ToE[]))
    {
        if (chunk.empty)
            return ConvertionStatus.empty;
        else
            return sink.put(cast(const ToE[]) chunk), ConvertionStatus.ok;
    }
}

unittest
{
    auto toubyte = CastingConverter!ubyte();
    auto sink = NaiveCatenator!ubyte();
    toubyte.convertChunk(""c, sink);
}

unittest
{
    auto toubyte = CastingConverter!ubyte();
    auto sink = NaiveCatenator!ubyte();

    auto stat1 = toubyte.convertChunk(""c, sink);
    assert(stat1 == ConvertionStatus.empty);

    auto stat2 = toubyte.convertChunk("\x00\x20"c, sink);
    assert(stat2 == ConvertionStatus.ok);

    assert(sink.data == [ 0x00, 0x20 ]);
}


//----------------------------------------------------------------------------//
// Chunk-Converter Chain
//----------------------------------------------------------------------------//

/*
 * Internally used for chaining two chunk-converters.
 */
private @system auto chainConverters(Conv1, Conv2)(Conv1 conv1, Conv2 conv2)
{
    return ConverterChain!(Conv1, Conv2)(conv1, conv2);
}

// ditto
private @system struct ConverterChain(Conv1, Conv2)
{
    void opAssign(typeof(this) rhs)
    {
        swap(this, rhs);
    }


    /*
     * Converts $(D chunk) into a temporary using $(D Conv1), then converts the
     * temporary into $(D sink) using $(D Conv2).
     */
    ConvertionStatus convertChunk(Chunk, Sink)(Chunk chunk, ref Sink sink)
    {
      /+
        struct ProxyOutput
        {
            void put(Chunk)(Chunk chunk)
            {
                conv2_.convertChunk(chunk, sink);
            }
        }
        ProxyOutput proxy;
      +/
        // @@@ workaround: inner struct can't access outer this
        // @@@ workaround: isOutputRange fails for inner struct
        // @@@ workaround: ICE(glue.c:694) '!vthis->csym'
        static struct ProxyOutput
        {
            void put(Chunk)(Chunk chunk)
            {
                this_.conv2_.convertChunk(chunk, *sink_);
            }
            ConverterChain* this_;
            Sink*           sink_;
        }
        auto proxy = ProxyOutput(&this, &sink);

        return conv1_.convertChunk(chunk, proxy);
    }

private:
    Conv1 conv1_;
    Conv2 conv2_;
}

unittest
{
    auto wconv = UTFTextConverter!wchar();
    auto uconv = UTFTextConverter! char();

    auto wuconv = chainConverters(wconv, uconv);
    auto sink = NaiveCatenator!char();

    wuconv.convertChunk(""c, sink);
    wuconv.convertChunk(""w, sink);
    wuconv.convertChunk(""d, sink);
}

unittest
{
    auto wconv = UTFTextConverter!wchar();
    auto uconv = UTFTextConverter! char();

    auto wuconv = chainConverters(wconv, uconv);
    auto sink = NaiveCatenator!char();

    auto stat1 = wuconv.convertChunk(""c, sink);
    assert(stat1 == ConvertionStatus.empty);
    assert(sink.data.empty);

    auto stat2 = wuconv.convertChunk(""w, sink);
    assert(stat2 == ConvertionStatus.empty);
    assert(sink.data.empty);

    auto stat3 = wuconv.convertChunk(""d, sink);
    assert(stat3 == ConvertionStatus.empty);
    assert(sink.data.empty);
}

unittest
{
    auto wconv = UTFTextConverter!wchar();
    auto uconv = UTFTextConverter! char();

    auto wuconv = chainConverters(wconv, uconv);
    auto sink = NaiveCatenator! char();

    auto stat1 = wuconv.convertChunk("\u0000\u007f\u0080\u07ff"c, sink);
    assert(stat1 == ConvertionStatus.ok);
    assert(!sink.data.empty);

    auto stat2 = wuconv.convertChunk("\u0800\ud7ff\ue000\ufffd"w, sink);
    assert(stat2 == ConvertionStatus.ok);
    assert(!sink.data.empty);

    auto stat3 = wuconv.convertChunk("\U00010000\U0001dc00\U0010ffff"d, sink);
    assert(stat3 == ConvertionStatus.ok);
    assert(!sink.data.empty);

    assert(sink.data ==
             "\u0000\u007f\u0080\u07ff\u0800\ud7ff\ue000\ufffd"
            ~"\U00010000\U0001dc00\U0010ffff"c);
}


//----------------------------------------------------------------------------//
// Range Adaptors for Converters
//----------------------------------------------------------------------------//

/*
 * $(D Input range) for reading $(D dchar)s from a multibyte input range
 * $(D Source) using a character-decoding converter $(D Decoder).
 */
@system struct DecodedTextReader(Source, Decoder)
        //if (isInputRange!(Source) && is(ElementType!Source : ubyte))
{
    this(Source source, Decoder decoder)
    {
        swap(source_, source);
        swap(decoder_, decoder);
        context_ = new Context;
    }

    void opAssign(typeof(this) rhs)
    {
        swap(this, rhs);
    }


    //----------------------------------------------------------------//
    // range primitive implementations
    //----------------------------------------------------------------//

    @property bool empty()
    {
        if (context_.front == -1)
            popFront;
        return context_.front == -1 && context_.queue.empty && source_.empty;
    }

    @property dchar front()
    {
        if (context_.front == -1)
            popFront;
        return cast(dchar) context_.front;
    }

    void popFront()
    {
        if (!context_.queue.empty)
        {
            readNext(context_.queue, context_.front) || assert(0);
        }
        else
        {
            context_.front = -1;
            cast(void) decoder_.convertCharacter(source_, this);
        }
    }

    // Read $(D c) virtually into the internal buffer.
    @safe void put(dchar c)
    {
        if (context_.front == -1)
            context_.front  = c;
        else
            context_.queue ~= c;
    }


    //----------------------------------------------------------------//
private:
    struct Context
    {
        int     front = -1;
        dstring queue;
    }
    Source   source_;
    Decoder  decoder_;
    Context* context_;
}

unittest
{
    alias DecodedTextReader!(ubyte[], UTF8Decoder) DTR;
    ubyte[] source;
    UTF8Decoder decoder;

    auto r1 = DTR(source, decoder);
    auto r2 = r1;
    r1 = r2;
}

unittest
{
    enum dstring codepoints =
        "\u0000\u007f\u0080\u07ff\u0800\ud7ff\ue000\ufffd\U00010000\U0010ffff";

    auto s = cast(ubyte[]) (cast(string) codepoints).dup;
    auto r = DecodedTextReader!(ubyte[], UTF8Decoder)(s, UTF8Decoder());

    size_t k = 0;
    for (; !r.empty; r.popFront, ++k)
    {
        assert(r.front == codepoints[k]);
    }
    assert(k == codepoints.length);
}


/*
 * $(D Output range) for writing sequence of data chunks into an output range
 * $(D Sink) with convertion by $(D Converter).
 */
@system struct ConvertedChunkWriter(Sink, Converter)
{
    this(Sink sink, Converter converter)
    {
        swap(sink_, sink);
        swap(converter_, converter);
    }

    void opAssign(typeof(this) rhs)
    {
        swap(this, rhs);
    }

    //----------------------------------------------------------------//
    // output range primitive
    //----------------------------------------------------------------//

    void put(Chunk)(Chunk chunk)
    {
        cast(void) converter_.convertChunk(chunk, sink_);
    }


    //----------------------------------------------------------------//
private:
    Sink      sink_;
    Converter converter_;
}

unittest
{
    alias ConvertedChunkWriter!(NaiveCatenator!char, UTFTextConverter!char) CCW;
    NaiveCatenator!char sink;
    UTFTextConverter!char encoder;

    auto w1 = CCW(sink, encoder);
    auto w2 = w1;
    w1 = w2;
}

unittest
{
    enum dstring codepoints =
        "\u0000\u007f\u0080\u07ff\u0800\ud7ff\ue000\ufffd\U00010000\U0010ffff";

    auto sink = NaiveCatenator!char();
    auto conv = UTFTextConverter!char();

    alias .ConvertedChunkWriter!(typeof(sink)*, typeof(conv)) ConvertedChunkWriter;
    auto wr = ConvertedChunkWriter(&sink, conv);

    string s, w, d;
    wr.put(s = codepoints);
    wr.put(w = codepoints);
    wr.put(d = codepoints);

    string v = codepoints ~ codepoints ~ codepoints;
    assert(sink.data == v);
}


//----------------------------------------------------------------------------//

/*
 * Range utility for reading out a front element of $(D r) into $(D item) as
 * a value of type $(D E).  Returns $(D false) if $(D r) is empty.
 */
private bool readNext(R, E)(ref R r, ref E item)
        if (!isArray!(R) && isInputRange!(R) && is(ElementType!R : E))
{
    if (r.empty)
    {
        return false;
    }
    else
    {
        item = r.front;
        r.popFront;
        return true;
    }
}

unittest
{
    static struct R
    {
        byte i = 4;
        @property bool empty() { return i == 0; }
        @property byte front() { return i; }
        void popFront() { --i; }
    }
    static assert(isInputRange!(R));
    static assert(is(ElementType!R == byte));

    R r;
    byte  b;
    short s;
    int   i;
    real  n;

    readNext(r, b) || assert(0);
    readNext(r, s) || assert(0);
    readNext(r, i) || assert(0);
    readNext(r, n) || assert(0);
    assert(b == 4);
    assert(s == 3);
    assert(i == 2);
    assert(n == 1);
    assert(r.empty);
    readNext(r, b) && assert(0);
}

// For bypassing this: typeof(string.front) == dchar
private bool readNext(A, E)(ref A arr, ref E item)
        if (isArray!(A) && is(typeof(arr[0]) : E))
{
    if (arr.length == 0)
    {
        return false;
    }
    else
    {
        item = arr[0];
        arr = arr[1 .. $];
        return true;
    }
}

unittest
{
    int[] r = [ 1, 2, 3 ];
    int   e;

    r.readNext(e) || assert(0);
    assert(e == 1);

    r.readNext(e) || assert(0);
    assert(e == 2);

    r.readNext(e) || assert(0);
    assert(e == 3);

    assert(r.empty);
    r.readNext(e) && assert(0);
}

