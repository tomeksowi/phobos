# Makefile to build linux D runtime library libphobos.a.
# Targets:
#	make
#		Same as make unittest
#	make libphobos.a
#		Build libphobos.a
#	make clean
#		Delete unneeded files created by build process
#	make unittest
#		Build libphobos.a, build and run unit tests

CFLAGS=-O
#CFLAGS=-g

DFLAGS=-O -release
#DFLAGS=-unittest

CC=gcc
#DMD=/dmd/bin/dmd
DMD=dmd

.c.o:
	$(CC) -c $(CFLAGS) $*.c

.cpp.o:
	g++ -c $(CFLAGS) $*.cpp

.d.o:
	$(DMD) -c $(DFLAGS) $*.d

.asm.o:
	$(CC) -c $*.asm

targets : unittest

test.o : test.d
	$(DMD) -c test -g

test : test.o libphobos.a
	$(CC) -o $@ test.o libphobos.a -lpthread -lm -g

unittest : unittest.o libphobos.a
	$(CC) -o $@ unittest.o libphobos.a -lpthread -lm -g

unittest.o : unittest.d
	$(DMD) -c unittest

OBJS= asserterror.o deh2.o switch.o complex.o gcstats.o \
	critical.o object.o monitor.o arraycat.o invariant.o \
	dmain2.o outofmemory.o aaA.o adi.o aApply.o file.o \
	compiler.o system.o moduleinit.o md5.o base64.o \
	cast.o path.o string.o memset.o math.o mmfile.o \
	outbuffer.o ctype.o regexp.o random.o linux.o linuxsocket.o \
	stream.o cstream.o switcherr.o array.o gc.o \
	qsort.o thread.o obj.o utf.o uri.o \
	crc32.o conv.o arraycast.o errno.o alloca.o cmath2.o \
	process.o syserror.o \
	socket.o socketstream.o stdarg.o stdio.o format.o \
	perf.o openrj.o uni.o trace.o boxer.o \
	demangle.o \
	ti_wchar.o ti_uint.o ti_short.o ti_ushort.o \
	ti_byte.o ti_ubyte.o ti_long.o ti_ulong.o ti_ptr.o \
	ti_float.o ti_double.o ti_real.o ti_delegate.o \
	ti_creal.o ti_ireal.o ti_cfloat.o ti_ifloat.o \
	ti_cdouble.o ti_idouble.o \
	ti_Aa.o ti_AC.o ti_Ag.o ti_Aubyte.o ti_Aushort.o ti_Ashort.o \
	ti_C.o ti_int.o ti_char.o ti_dchar.o ti_Adchar.o ti_bit.o \
	ti_Aint.o ti_Auint.o ti_Along.o ti_Aulong.o ti_Awchar.o \
	ti_Afloat.o ti_Adouble.o ti_Areal.o \
	ti_Acfloat.o ti_Acdouble.o ti_Acreal.o \
	ti_Abit.o ti_void.o \
	date.o dateparse.o llmath.o math2.o Czlib.o Dzlib.o zip.o recls.o

ZLIB_OBJS= etc/c/zlib/adler32.o etc/c/zlib/compress.o \
	etc/c/zlib/crc32.o etc/c/zlib/gzio.o \
	etc/c/zlib/uncompr.o etc/c/zlib/deflate.o \
	etc/c/zlib/trees.o etc/c/zlib/zutil.o \
	etc/c/zlib/inflate.o etc/c/zlib/infback.o \
	etc/c/zlib/inftrees.o etc/c/zlib/inffast.o

RECLS_OBJS= etc/c/recls/recls_api.o		\
	etc/c/recls/recls_fileinfo.o		\
	etc/c/recls/recls_internal.o		\
	etc/c/recls/recls_util.o		\
	etc/c/recls/recls_api_unix.o		\
	etc/c/recls/recls_fileinfo_unix.o	\
	etc/c/recls/recls_util_unix.o

GC_OBJS= internal/gc/gc.o internal/gc/gcx.o \
	internal/gc/gcbits.o internal/gc/gclinux.o

SRC=	errno.c object.d unittest.d crc32.d gcstats.d

SRC_STD= std/zlib.d std/zip.d std/stdint.d std/conv.d std/utf.d std/uri.d \
	std/gc.d std/math.d std/string.d std/path.d std/date.d \
	std/ctype.d std/file.d std/compiler.d std/system.d std/moduleinit.d \
	std/outbuffer.d std/math2.d std/thread.d std/md5.d std/base64.d \
	std/asserterror.d std/dateparse.d std/outofmemory.d std/mmfile.d \
	std/intrinsic.d std/array.d std/switcherr.d std/syserror.d \
	std/regexp.d std/random.d std/stream.d std/process.d std/recls.d \
	std/socket.d std/socketstream.d std/loader.d std/stdarg.d \
	std/stdio.d std/format.d std/perf.d std/openrj.d std/uni.d \
	std/boxer.d std/cstream.d std/demangle.d

SRC_STD_C= std/c/process.d std/c/stdlib.d std/c/time.d std/c/stdio.d \
	std/c/math.d std/c/stdarg.d std/c/stddef.d

SRC_TI=	\
	std/typeinfo/ti_wchar.d std/typeinfo/ti_uint.d \
	std/typeinfo/ti_short.d std/typeinfo/ti_ushort.d \
	std/typeinfo/ti_byte.d std/typeinfo/ti_ubyte.d \
	std/typeinfo/ti_long.d std/typeinfo/ti_ulong.d \
	std/typeinfo/ti_ptr.d std/typeinfo/ti_bit.d \
	std/typeinfo/ti_float.d std/typeinfo/ti_double.d \
	std/typeinfo/ti_real.d std/typeinfo/ti_delegate.d \
	std/typeinfo/ti_creal.d std/typeinfo/ti_ireal.d \
	std/typeinfo/ti_cfloat.d std/typeinfo/ti_ifloat.d \
	std/typeinfo/ti_cdouble.d std/typeinfo/ti_idouble.d \
	std/typeinfo/ti_Adchar.d std/typeinfo/ti_Aubyte.d \
	std/typeinfo/ti_Aushort.d std/typeinfo/ti_Ashort.d \
	std/typeinfo/ti_Aa.d std/typeinfo/ti_Ag.d \
	std/typeinfo/ti_AC.d std/typeinfo/ti_C.d \
	std/typeinfo/ti_int.d std/typeinfo/ti_char.d \
	std/typeinfo/ti_Aint.d std/typeinfo/ti_Auint.d \
	std/typeinfo/ti_Along.d std/typeinfo/ti_Aulong.d \
	std/typeinfo/ti_Afloat.d std/typeinfo/ti_Adouble.d \
	std/typeinfo/ti_Areal.d \
	std/typeinfo/ti_Acfloat.d std/typeinfo/ti_Acdouble.d \
	std/typeinfo/ti_Acreal.d \
	std/typeinfo/ti_Abit.d std/typeinfo/ti_void.d \
	std/typeinfo/ti_Awchar.d std/typeinfo/ti_dchar.d

SRC_INT=	\
	internal/switch.d internal/complex.c internal/critical.c \
	internal/minit.asm internal/alloca.d internal/llmath.d internal/deh.c \
	internal/arraycat.d internal/invariant.d internal/monitor.c \
	internal/memset.d internal/arraycast.d internal/aaA.d internal/adi.d \
	internal/dmain2.d internal/cast.d internal/qsort.d internal/deh2.d \
	internal/cmath2.d internal/obj.d internal/mars.h internal/aApply.d \
	internal/object.d internal/trace.d internal/qsort2.d

SRC_STD_WIN= std/windows/registry.d \
	std/windows/iunknown.d std/windows/charset.d

SRC_STD_C_WIN= std/c/windows/windows.d std/c/windows/com.d \
	std/c/windows/winsock.d

SRC_STD_C_LINUX= std/c/linux/linux.d std/c/linux/linuxextern.d \
	std/c/linux/socket.d

SRC_ETC=  etc/gamma.d etc/realtest.d

SRC_ETC_C= etc/c/zlib.d

SRC_ZLIB= etc/c/zlib\trees.h \
	etc/c/zlib\inffixed.h \
	etc/c/zlib\inffast.h \
	etc/c/zlib\crc32.h \
	etc/c/zlib\algorithm.txt \
	etc/c/zlib\uncompr.c \
	etc/c/zlib\compress.c \
	etc/c/zlib\deflate.h \
	etc/c/zlib\inftrees.h \
	etc/c/zlib\infback.c \
	etc/c/zlib\zutil.c \
	etc/c/zlib\crc32.c \
	etc/c/zlib\inflate.h \
	etc/c/zlib\example.c \
	etc/c/zlib\inffast.c \
	etc/c/zlib\trees.c \
	etc/c/zlib\inflate.c \
	etc/c/zlib\gzio.c \
	etc/c/zlib\zconf.h \
	etc/c/zlib\zconf.in.h \
	etc/c/zlib\minigzip.c \
	etc/c/zlib\deflate.c \
	etc/c/zlib\inftrees.c \
	etc/c/zlib\zutil.h \
	etc/c/zlib\zlib.3 \
	etc/c/zlib\zlib.h \
	etc/c/zlib\adler32.c \
	etc/c/zlib\ChangeLog \
	etc/c/zlib\zlib.html \
	etc/c/zlib\README \
	etc/c/zlib\win32.mak \
	etc/c/zlib\linux.mak

SRC_GC= internal/gc/gc.d \
	internal/gc/gcx.d \
	internal/gc/gcstub.d \
	internal/gc/gcbits.d \
	internal/gc/win32.d \
	internal/gc/gclinux.d \
	internal/gc/testgc.d \
	internal/gc/win32.mak \
	internal/gc/linux.mak

SRC_STLSOFT= \
	etc/c/stlsoft/stlsoft_null_mutex.h \
	etc/c/stlsoft/unixstl_string_access.h \
	etc/c/stlsoft/unixstl.h \
	etc/c/stlsoft/winstl_tls_index.h \
	etc/c/stlsoft/unixstl_environment_variable.h \
	etc/c/stlsoft/unixstl_functionals.h \
	etc/c/stlsoft/unixstl_current_directory.h \
	etc/c/stlsoft/unixstl_limits.h \
	etc/c/stlsoft/unixstl_current_directory_scope.h \
	etc/c/stlsoft/unixstl_filesystem_traits.h \
	etc/c/stlsoft/unixstl_findfile_sequence.h \
	etc/c/stlsoft/unixstl_glob_sequence.h \
	etc/c/stlsoft/winstl.h \
	etc/c/stlsoft/winstl_atomic_functions.h \
	etc/c/stlsoft/stlsoft_cccap_gcc.h \
	etc/c/stlsoft/stlsoft_lock_scope.h \
	etc/c/stlsoft/unixstl_thread_mutex.h \
	etc/c/stlsoft/unixstl_spin_mutex.h \
	etc/c/stlsoft/unixstl_process_mutex.h \
	etc/c/stlsoft/stlsoft_null.h \
	etc/c/stlsoft/stlsoft_nulldef.h \
	etc/c/stlsoft/winstl_thread_mutex.h \
	etc/c/stlsoft/winstl_spin_mutex.h \
	etc/c/stlsoft/winstl_system_version.h \
	etc/c/stlsoft/winstl_findfile_sequence.h \
	etc/c/stlsoft/unixstl_readdir_sequence.h \
	etc/c/stlsoft/stlsoft.h \
	etc/c/stlsoft/stlsoft_static_initialisers.h \
	etc/c/stlsoft/stlsoft_iterator.h \
	etc/c/stlsoft/stlsoft_cccap_dmc.h \
	etc/c/stlsoft/winstl_filesystem_traits.h

SRC_RECLS= \
	etc/c/recls/recls_compiler.h \
	etc/c/recls/recls_language.h \
	etc/c/recls/recls_unix.h \
	etc/c/recls/recls_retcodes.h \
	etc/c/recls/recls_assert.h \
	etc/c/recls/recls_platform.h \
	etc/c/recls/recls_win32.h \
	etc/c/recls/recls.h \
	etc/c/recls/recls_util.h \
	etc/c/recls/recls_compiler_dmc.h \
	etc/c/recls/recls_compiler_gcc.h \
	etc/c/recls/recls_platform_types.h \
	etc/c/recls/recls_internal.h \
	etc/c/recls/recls_debug.h \
	etc/c/recls/recls_fileinfo_win32.cpp \
	etc/c/recls/recls_api_unix.cpp \
	etc/c/recls/recls_api.cpp \
	etc/c/recls/recls_util_win32.cpp \
	etc/c/recls/recls_util_unix.cpp \
	etc/c/recls/recls_util.cpp \
	etc/c/recls/recls_internal.cpp \
	etc/c/recls/recls_fileinfo.cpp \
	etc/c/recls/recls_defs.h \
	etc/c/recls/recls_fileinfo_unix.cpp \
	etc/c/recls/recls_api_win32.cpp \
	etc/c/recls/win32.mak \
	etc/c/recls/linux.mak \
	etc/c/recls/recls.lib

SRC_STLSOFT_NEW= \
	etc/c/stlsoft/winstl_file_path_buffer.h \
	etc/c/stlsoft/inetstl_connection.h \
	etc/c/stlsoft/inetstl_filesystem_traits.h \
	etc/c/stlsoft/inetstl_findfile_sequence.h \
	etc/c/stlsoft/inetstl_searchspec_sequence.h \
	etc/c/stlsoft/inetstl_session.h \
	etc/c/stlsoft/stlsoft.h \
	etc/c/stlsoft/stlsoft_allocator_base.h \
	etc/c/stlsoft/inetstl.h \
	etc/c/stlsoft/stlsoft_auto_buffer.h \
	etc/c/stlsoft/stlsoft_cccap_dmc.h \
	etc/c/stlsoft/stlsoft_cccap_gcc.h \
	etc/c/stlsoft/stlsoft_char_traits.h \
	etc/c/stlsoft/stlsoft_constraints.h \
	etc/c/stlsoft/stlsoft_exceptions.h \
	etc/c/stlsoft/stlsoft_iterator.h \
	etc/c/stlsoft/stlsoft_meta.h \
	etc/c/stlsoft/stlsoft_new_allocator.h \
	etc/c/stlsoft/stlsoft_any_caster.h \
	etc/c/stlsoft/stlsoft_nulldef.h \
	etc/c/stlsoft/stlsoft_sap_cast.h \
	etc/c/stlsoft/stlsoft_searchspec_sequence.h \
	etc/c/stlsoft/stlsoft_sign_traits.h \
	etc/c/stlsoft/stlsoft_simple_algorithms.h \
	etc/c/stlsoft/stlsoft_simple_string.h \
	etc/c/stlsoft/stlsoft_size_traits.h \
	etc/c/stlsoft/stlsoft_string_access.h \
	etc/c/stlsoft/stlsoft_string_tokeniser.h \
	etc/c/stlsoft/stlsoft_type_traits.h \
	etc/c/stlsoft/unixstl.h \
	etc/c/stlsoft/unixstl_filesystem_traits.h \
	etc/c/stlsoft/unixstl_file_path_buffer.h \
	etc/c/stlsoft/unixstl_glob_sequence.h \
	etc/c/stlsoft/unixstl_string_access.h \
	etc/c/stlsoft/unixstl_thread_mutex.h \
	etc/c/stlsoft/winstl.h \
	etc/c/stlsoft/winstl_atomic_functions.h \
	etc/c/stlsoft/winstl_char_conversions.h \
	etc/c/stlsoft/winstl_filesystem_traits.h \
	etc/c/stlsoft/winstl_spin_mutex.h \
	etc/c/stlsoft/winstl_findfile_sequence.h \
	etc/c/stlsoft/winstl_processheap_allocator.h \
	etc/c/stlsoft/winstl_system_version.h \
	etc/c/stlsoft/stlsoft_null.h

SRC_RECLS_NEW= \
	etc/c/recls/recls_compiler_gcc.h \
	etc/c/recls/recls_retcodes.h \
	etc/c/recls/EntryFunctions.h \
	etc/c/recls/recls_platform_types.h \
	etc/c/recls/recls.h \
	etc/c/recls/recls_wininet_dl.h \
	etc/c/recls/ReclsFileSearch.h \
	etc/c/recls/ReclsFileSearchDirectoryNode_unix.cpp \
	etc/c/recls/ReclsFileSearchDirectoryNode_unix.h \
	etc/c/recls/ReclsFileSearchDirectoryNode_win32.cpp \
	etc/c/recls/ReclsFileSearchDirectoryNode_win32.h \
	etc/c/recls/recls_wininet_dl.cpp \
	etc/c/recls/ReclsFileSearch_unix.cpp \
	etc/c/recls/ReclsFileSearch_win32.cpp \
	etc/c/recls/recls_win32.h \
	etc/c/recls/ReclsFtpSearch.h \
	etc/c/recls/ReclsFtpSearchDirectoryNode_win32.cpp \
	etc/c/recls/ReclsFtpSearchDirectoryNode_win32.h \
	etc/c/recls/recls_util_win32.cpp \
	etc/c/recls/ReclsFtpSearch_win32.cpp \
	etc/c/recls/recls_util_unix.cpp \
	etc/c/recls/recls_api.cpp \
	etc/c/recls/recls_util.h \
	etc/c/recls/recls_api_unix.cpp \
	etc/c/recls/recls_api_win32.cpp \
	etc/c/recls/recls_util.cpp \
	etc/c/recls/recls_assert.h \
	etc/c/recls/recls_compiler.h \
	etc/c/recls/recls_compiler_dmc.h \
	etc/c/recls/recls_platform.h \
	etc/c/recls/recls_debug.h \
	etc/c/recls/recls_defs.h \
	etc/c/recls/recls_fileinfo.cpp \
	etc/c/recls/recls_fileinfo_unix.cpp \
	etc/c/recls/recls_fileinfo_win32.cpp \
	etc/c/recls/recls_unix.h \
	etc/c/recls/recls_ftp.h \
	etc/c/recls/recls_ftp_api_win32.cpp \
	etc/c/recls/recls_internal.cpp \
	etc/c/recls/recls_internal.h \
	etc/c/recls/recls_roots_win32.cpp \
	etc/c/recls/recls_language.h \
	etc/c/recls/recls_roots_unix.cpp \
	etc/c/recls/win32.mak \
	etc/c/recls/linux.mak

ALLSRCS = $(SRC) $(SRC_STD) $(SRC_STD_C) $(SRC_TI) $(SRC_INT) $(SRC_STD_WIN) \
	$(SRC_STD_C_WIN) $(SRC_STD_C_LINUX) $(SRC_ETC) $(SRC_ETC_C) \
	$(SRC_ZLIB) $(SRC_GC) \
	$(SRC_RECLS) $(SRC_STLSOFT)


#libphobos.a : $(OBJS) internal/gc/dmgc.a linux.mak
libphobos.a : $(OBJS) internal/gc/dmgc.a $(ZLIB_OBJS) $(RECLS_OBJS) linux.mak
	ar -r $@ $(OBJS) $(ZLIB_OBJS) $(GC_OBJS) $(RECLS_OBJS)

###########################################################

internal/gc/dmgc.a:
#	cd internal/gc
#	make -f linux.mak dmgc.a
#	cd ../..
	make -C ./internal/gc -f linux.mak dmgc.a

$(RECLS_OBJS):
#	cd etc/c/recls
#	make -f linux.mak
#	cd ../../..
	make -C ./etc/c/recls -f linux.mak

$(ZLIB_OBJS):
#	cd etc/c/zlib
#	make -f linux.mak
#	cd ../../..
	make -C ./etc/c/zlib -f linux.mak

###

crc32.o : crc32.d
	$(DMD) -c $(DFLAGS) crc32.d

errno.o : errno.c

gcstats.o : gcstats.d
	$(DMD) -c $(DFLAGS) gcstats.d

### internal

aaA.o : internal/aaA.d
	$(DMD) -c $(DFLAGS) internal/aaA.d

aApply.o : internal/aApply.d
	$(DMD) -c $(DFLAGS) internal/aApply.d

adi.o : internal/adi.d
	$(DMD) -c $(DFLAGS) internal/adi.d

alloca.o : internal/alloca.d
	$(DMD) -c $(DFLAGS) internal/alloca.d

arraycast.o : internal/arraycast.d
	$(DMD) -c $(DFLAGS) internal/arraycast.d

arraycat.o : internal/arraycat.d
	$(DMD) -c $(DFLAGS) internal/arraycat.d

cast.o : internal/cast.d
	$(DMD) -c $(DFLAGS) internal/cast.d

cmath2.o : internal/cmath2.d
	$(DMD) -c $(DFLAGS) internal/cmath2.d

complex.o : internal/complex.c
	$(CC) -c $(CFLAGS) internal/complex.c

critical.o : internal/critical.c
	$(CC) -c $(CFLAGS) internal/critical.c

#deh.o : internal/mars.h internal/deh.cA
#	$(CC) -c $(CFLAGS) internal/deh.c

deh2.o : internal/deh2.d
	$(DMD) -c $(DFLAGS) -release internal/deh2.d

dmain2.o : internal/dmain2.d
	$(DMD) -c $(DFLAGS) internal/dmain2.d

invariant.o : internal/invariant.d
	$(DMD) -c $(DFLAGS) internal/invariant.d

llmath.o : internal/llmath.d
	$(DMD) -c $(DFLAGS) internal/llmath.d

memset.o : internal/memset.d
	$(DMD) -c $(DFLAGS) internal/memset.d

#minit.o : internal/minit.asm
#	$(CC) -c internal/minit.asm

monitor.o : internal/mars.h internal/monitor.c
	$(CC) -c $(CFLAGS) internal/monitor.c

obj.o : internal/obj.d
	$(DMD) -c $(DFLAGS) internal/obj.d

object.o : internal/object.d
	$(DMD) -c $(DFLAGS) internal/object.d

qsort.o : internal/qsort.d
	$(DMD) -c $(DFLAGS) internal/qsort.d

switch.o : internal/switch.d
	$(DMD) -c $(DFLAGS) internal/switch.d

trace.o : internal/trace.d
	$(DMD) -c $(DFLAGS) internal/trace.d

### std

array.o : std/array.d
	$(DMD) -c $(DFLAGS) std/array.d

asserterror.o : std/asserterror.d
	$(DMD) -c $(DFLAGS) std/asserterror.d

base64.o : std/base64.d
	$(DMD) -c $(DFLAGS) std/base64.d

boxer.o : std/boxer.d
	$(DMD) -c $(DFLAGS) std/boxer.d

compiler.o : std/compiler.d
	$(DMD) -c $(DFLAGS) std/compiler.d

conv.o : std/conv.d
	$(DMD) -c $(DFLAGS) std/conv.d

cstream.o : std/cstream.d
	$(DMD) -c $(DFLAGS) std/cstream.d

ctype.o : std/ctype.d
	$(DMD) -c $(DFLAGS) std/ctype.d

date.o : std/dateparse.d std/date.d
	$(DMD) -c $(DFLAGS) std/date.d

dateparse.o : std/dateparse.d std/date.d
	$(DMD) -c $(DFLAGS) std/dateparse.d

demangle.o : std/demangle.d
	$(DMD) -c $(DFLAGS) std/demangle.d

file.o : std/file.d
	$(DMD) -c $(DFLAGS) std/file.d

format.o : std/format.d
	$(DMD) -c $(DFLAGS) std/format.d

gc.o : std/gc.d
	$(DMD) -c $(DFLAGS) std/gc.d

math.o : std/math.d
	$(DMD) -c $(DFLAGS) std/math.d

math2.o : std/math2.d
	$(DMD) -c $(DFLAGS) std/math2.d

md5.o : std/md5.d
	$(DMD) -c $(DFLAGS) std/md5.d

mmfile.o : std/mmfile.d
	$(DMD) -c $(DFLAGS) std/mmfile.d

moduleinit.o : std/moduleinit.d
	$(DMD) -c $(DFLAGS) std/moduleinit.d

openrj.o : std/openrj.d
	$(DMD) -c $(DFLAGS) std/openrj.d

outbuffer.o : std/outbuffer.d
	$(DMD) -c $(DFLAGS) std/outbuffer.d

outofmemory.o : std/outofmemory.d
	$(DMD) -c $(DFLAGS) std/outofmemory.d

path.o : std/path.d
	$(DMD) -c $(DFLAGS) std/path.d

perf.o : std/perf.d
	$(DMD) -c $(DFLAGS) std/perf.d

process.o : std/process.d
	$(DMD) -c $(DFLAGS) std/process.d

random.o : std/random.d
	$(DMD) -c $(DFLAGS) std/random.d

recls.o : std/recls.d
	$(DMD) -c $(DFLAGS) std/recls.d

regexp.o : std/regexp.d
	$(DMD) -c $(DFLAGS) std/regexp.d

socket.o : std/socket.d
	$(DMD) -c $(DFLAGS) std/socket.d

socketstream.o : std/socketstream.d
	$(DMD) -c $(DFLAGS) std/socketstream.d

stdio.o : std/stdio.d
	$(DMD) -c $(DFLAGS) std/stdio.d

stream.o : std/stream.d
	$(DMD) -c $(DFLAGS) -d std/stream.d

string.o : std/string.d
	$(DMD) -c $(DFLAGS) std/string.d

switcherr.o : std/switcherr.d
	$(DMD) -c $(DFLAGS) std/switcherr.d

system.o : std/system.d
	$(DMD) -c $(DFLAGS) std/system.d

syserror.o : std/syserror.d
	$(DMD) -c $(DFLAGS) std/syserror.d

thread.o : std/thread.d
	$(DMD) -c $(DFLAGS) std/thread.d

uri.o : std/uri.d
	$(DMD) -c $(DFLAGS) std/uri.d

uni.o : std/uni.d
	$(DMD) -c $(DFLAGS) std/uni.d

utf.o : std/utf.d
	$(DMD) -c $(DFLAGS) std/utf.d

Dzlib.o : std/zlib.d
	$(DMD) -c $(DFLAGS) std/zlib.d -ofDzlib.o

zip.o : std/zip.d
	$(DMD) -c $(DFLAGS) std/zip.d

### std/c

stdarg.o : std/c/stdarg.d
	$(DMD) -c $(DFLAGS) std/c/stdarg.d

### std/c/linux

linux.o : std/c/linux/linux.d
	$(DMD) -c $(DFLAGS) std/c/linux/linux.d

linuxsocket.o : std/c/linux/socket.d
	$(DMD) -c $(DFLAGS) std/c/linux/socket.d -oflinuxsocket.o

### etc

### etc/c

Czlib.o : etc/c/zlib.d
	$(DMD) -c $(DFLAGS) etc/c/zlib.d -ofCzlib.o

### std/typeinfo

ti_void.o : std/typeinfo/ti_void.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_void.d

ti_wchar.o : std/typeinfo/ti_wchar.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_wchar.d

ti_dchar.o : std/typeinfo/ti_dchar.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_dchar.d

ti_uint.o : std/typeinfo/ti_uint.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_uint.d

ti_short.o : std/typeinfo/ti_short.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_short.d

ti_ushort.o : std/typeinfo/ti_ushort.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_ushort.d

ti_byte.o : std/typeinfo/ti_byte.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_byte.d

ti_ubyte.o : std/typeinfo/ti_ubyte.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_ubyte.d

ti_long.o : std/typeinfo/ti_long.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_long.d

ti_ulong.o : std/typeinfo/ti_ulong.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_ulong.d

ti_ptr.o : std/typeinfo/ti_ptr.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_ptr.d

ti_float.o : std/typeinfo/ti_float.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_float.d

ti_double.o : std/typeinfo/ti_double.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_double.d

ti_real.o : std/typeinfo/ti_real.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_real.d

ti_delegate.o : std/typeinfo/ti_delegate.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_delegate.d

ti_creal.o : std/typeinfo/ti_creal.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_creal.d

ti_ireal.o : std/typeinfo/ti_ireal.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_ireal.d

ti_cfloat.o : std/typeinfo/ti_cfloat.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_cfloat.d

ti_ifloat.o : std/typeinfo/ti_ifloat.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_ifloat.d

ti_cdouble.o : std/typeinfo/ti_cdouble.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_cdouble.d

ti_idouble.o : std/typeinfo/ti_idouble.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_idouble.d

ti_Aa.o : std/typeinfo/ti_Aa.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_Aa.d

ti_AC.o : std/typeinfo/ti_AC.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_AC.d

ti_Ag.o : std/typeinfo/ti_Ag.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_Ag.d

ti_Abit.o : std/typeinfo/ti_Abit.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_Abit.d

ti_Aubyte.o : std/typeinfo/ti_Aubyte.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_Aubyte.d

ti_Aushort.o : std/typeinfo/ti_Aushort.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_Aushort.d

ti_Ashort.o : std/typeinfo/ti_Ashort.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_Ashort.d

ti_Auint.o : std/typeinfo/ti_Auint.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_Auint.d

ti_Aint.o : std/typeinfo/ti_Aint.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_Aint.d

ti_Aulong.o : std/typeinfo/ti_Aulong.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_Aulong.d

ti_Along.o : std/typeinfo/ti_Along.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_Along.d

ti_Afloat.o : std/typeinfo/ti_Afloat.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_Afloat.d

ti_Adouble.o : std/typeinfo/ti_Adouble.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_Adouble.d

ti_Areal.o : std/typeinfo/ti_Areal.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_Areal.d

ti_Acfloat.o : std/typeinfo/ti_Acfloat.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_Acfloat.d

ti_Acdouble.o : std/typeinfo/ti_Acdouble.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_Acdouble.d

ti_Acreal.o : std/typeinfo/ti_Acreal.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_Acreal.d

ti_Awchar.o : std/typeinfo/ti_Awchar.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_Awchar.d

ti_Adchar.o : std/typeinfo/ti_Adchar.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_Adchar.d

ti_C.o : std/typeinfo/ti_C.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_C.d

ti_char.o : std/typeinfo/ti_char.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_char.d

ti_int.o : std/typeinfo/ti_int.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_int.d

ti_bit.o : std/typeinfo/ti_bit.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_bit.d


##########################################################333

zip : $(ALLSRCS) linux.mak win32.mak phoboslicense.txt
	rm phobos.zip
	zip phobos $(ALLSRCS) linux.mak win32.mak phoboslicense.txt

clean:
	rm $(OBJS) unittest unittest.o