/* /////////////////////////////////////////////////////////////////////////////
 * File:        recls_util_win32.cpp
 *
 * Purpose:     Win32 utility functions for the recls API.
 *
 * Created:     17th August 2003
 * Updated:     27th November 2003
 *
 * License:     (Licensed under the Synesis Software Standard Source License)
 *
 *              Copyright (C) 2002-2003, Synesis Software Pty Ltd.
 *
 *              All rights reserved.
 *
 *              www:        http://www.synesis.com.au/software
 *                          http://www.recls.org/
 *
 *              email:      submissions@recls.org  for submissions
 *                          admin@recls.org        for other enquiries
 *
 *              Redistribution and use in source and binary forms, with or
 *              without modification, are permitted provided that the following
 *              conditions are met:
 *
 *              (i) Redistributions of source code must retain the above
 *              copyright notice and contact information, this list of
 *              conditions and the following disclaimer.
 *
 *              (ii) Any derived versions of this software (howsoever modified)
 *              remain the sole property of Synesis Software.
 *
 *              (iii) Any derived versions of this software (howsoever modified)
 *              remain subject to all these conditions.
 *
 *              (iv) Neither the name of Synesis Software nor the names of any
 *              subdivisions, employees or agents of Synesis Software, nor the
 *              names of any other contributors to this software may be used to
 *              endorse or promote products derived from this software without
 *              specific prior written permission.
 *
 *              This source code is provided by Synesis Software "as is" and any
 *              warranties, whether expressed or implied, including, but not
 *              limited to, the implied warranties of merchantability and
 *              fitness for a particular purpose are disclaimed. In no event
 *              shall the Synesis Software be liable for any direct, indirect,
 *              incidental, special, exemplary, or consequential damages
 *              (including, but not limited to, procurement of substitute goods
 *              or services; loss of use, data, or profits; or business
 *              interruption) however caused and on any theory of liability,
 *              whether in contract, strict liability, or tort (including
 *              negligence or otherwise) arising in any way out of the use of
 *              this software, even if advised of the possibility of such
 *              damage.
 *
 * ////////////////////////////////////////////////////////////////////////// */


/* /////////////////////////////////////////////////////////////////////////////
 * Includes
 */

#include "recls.h"
#include "recls_internal.h"
#include "recls_assert.h"
#include "recls_util.h"

#include <stlsoft_nulldef.h>

#include <unixstl_filesystem_traits.h>

#include <sys/types.h>
#include <sys/stat.h>

#include <errno.h>

/* /////////////////////////////////////////////////////////////////////////////
 * Namespace
 */

#if !defined(RECLS_NO_NAMESPACE)
namespace recls
{
#endif /* !RECLS_NO_NAMESPACE */

unixstl_ns_using(filesystem_traits)

/* ////////////////////////////////////////////////////////////////////////// */

RECLS_LINKAGE_C recls_bool_t file_exists(recls_char_t const *f)
{
    struct stat st;

    return 0 == stat(f, &st) || errno != ENOENT;
}

RECLS_LINKAGE_C size_t count_dir_parts_a(recls_char_a_t const *begin, recls_char_a_t const *end)
{
    return count_char_instances_a(begin, end, unixstl_ns_qual(filesystem_traits)<recls_char_a_t>::path_name_separator());
}

#if 0
RECLS_LINKAGE_C size_t count_dir_parts_w(recls_char_w_t const *begin, recls_char_w_t const *end)
{
    return count_char_instances_w(begin, end, unixstl_ns_qual(filesystem_traits)<recls_char_w_t>::path_name_separator());
}
#endif /* 0 */

/* /////////////////////////////////////////////////////////////////////////////
 * Namespace
 */

#if !defined(RECLS_NO_NAMESPACE)
} /* namespace recls */
#endif /* !RECLS_NO_NAMESPACE */

/* ////////////////////////////////////////////////////////////////////////// */