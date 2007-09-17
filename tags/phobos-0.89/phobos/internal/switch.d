
import std.c.stdio;
import std.string;

/******************************************************
 * Support for switch statements switching on strings.
 * Input:
 *	table[]		sorted array of strings generated by compiler
 *	ca		string to look up in table
 * Output:
 *	result		index of match in table[]
 *			-1 if not in table
 */

extern (C):

int _d_switch_string(char[][] table, char[] ca)
    in
    {
	//printf("in _d_switch_string()\n");
	assert(table.length >= 0);
	assert(ca.length >= 0);

	// Make sure table[] is sorted correctly
	int j;

	for (j = 1; j < table.length; j++)
	{
	    int len1 = table[j - 1].length;
	    int len2 = table[j].length;

	    assert(len1 <= len2);
	    if (len1 == len2)
	    {
		int ci;

		ci = memcmp(table[j - 1], table[j], len1);
		assert(ci < 0);	// ci==0 means a duplicate
	    }
	}
    }
    out (result)
    {
	int i;
	int cj;

	//printf("out _d_switch_string()\n");
	if (result == -1)
	{
	    // Not found
	    for (i = 0; i < table.length; i++)
	    {
		if (table[i].length == ca.length)
		{   cj = memcmp(table[i], ca, ca.length);
		    assert(cj != 0);
		}
	    }
	}
	else
	{
	    assert(0 <= result && result < table.length);
	    for (i = 0; 1; i++)
	    {
		assert(i < table.length);
		if (table[i].length == ca.length)
		{
		    cj = memcmp(table[i], ca, ca.length);
		    if (cj == 0)
		    {
			assert(i == result);
			break;
		    }
		}
	    }
	}
    }
    body
    {
	//printf("body _d_switch_string()\n");
	int low;
	int high;
	int mid;
	int c;
	char[] pca;

	low = 0;
	high = table.length;

    /*
	// Print table
	printf("ca[] = '%s'\n", (char *)ca);
	for (mid = 0; mid < high; mid++)
	{
	    pca = table[mid];
	    printf("table[%d] = %d, '%s'\n", mid, pca.length, (char *)pca);
	}
    */
	if (high &&
	    ca.length >= table[0].length &&
	    ca.length <= table[high - 1].length)
	{
	    // Looking for 0 length string, which would only be at the beginning
	    if (ca.length == 0)
		return 0;

	    char c1 = ca[0];

	    // Do binary search
	    while (low < high)
	    {
		mid = (low + high) >> 1;
		pca = table[mid];
		c = ca.length - pca.length;
		if (c == 0)
		{
		    c = cast(byte)c1 - cast(byte)pca[0];
		    if (c == 0)
		    {
			c = memcmp(ca, pca, ca.length);
			if (c == 0)
			{   //printf("found %d\n", mid);
			    return mid;
			}
		    }
		}
		if (c < 0)
		{
		    high = mid;
		}
		else
		{
		    low = mid + 1;
		}
	    }
	}

	//printf("not found\n");
	return -1;		// not found
    }

unittest
{
    switch (cast(char []) "c")
    {
         case "coo":
         default:
             break;
    }
}

/**********************************
 * Same thing, but for wide chars.
 */

int _d_switch_ustring(wchar[][] table, wchar[] ca)
    in
    {
	//printf("in _d_switch_ustring()\n");
	assert(table.length >= 0);
	assert(ca.length >= 0);

	// Make sure table[] is sorted correctly
	int j;

	for (j = 1; j < table.length; j++)
	{
	    int len1 = table[j - 1].length;
	    int len2 = table[j].length;

	    assert(len1 <= len2);
	    if (len1 == len2)
	    {
		int c;

		c = memcmp(table[j - 1], table[j], len1 * wchar.size);
		assert(c < 0);	// c==0 means a duplicate
	    }
	}
    }
    out (result)
    {
	int i;
	int c;

	//printf("out _d_switch_string()\n");
	if (result == -1)
	{
	    // Not found
	    for (i = 0; i < table.length; i++)
	    {
		if (table[i].length == ca.length)
		{   c = memcmp(table[i], ca, ca.length * wchar.size);
		    assert(c != 0);
		}
	    }
	}
	else
	{
	    assert(0 <= result && result < table.length);
	    for (i = 0; 1; i++)
	    {
		assert(i < table.length);
		if (table[i].length == ca.length)
		{
		    c = memcmp(table[i], ca, ca.length * wchar.size);
		    if (c == 0)
		    {
			assert(i == result);
			break;
		    }
		}
	    }
	}
    }
    body
    {
	//printf("body _d_switch_ustring()\n");
	int low;
	int high;
	int mid;
	int c;
	wchar[] pca;

	low = 0;
	high = table.length;

    /*
	// Print table
	wprintf("ca[] = '%.*s'\n", ca);
	for (mid = 0; mid < high; mid++)
	{
	    pca = table[mid];
	    wprintf("table[%d] = %d, '%.*s'\n", mid, pca.length, pca);
	}
    */

	// Do binary search
	while (low < high)
	{
	    mid = (low + high) >> 1;
	    pca = table[mid];
	    c = ca.length - pca.length;
	    if (c == 0)
	    {
		c = memcmp(ca, pca, ca.length * wchar.size);
		if (c == 0)
		{   //printf("found %d\n", mid);
		    return mid;
		}
	    }
	    if (c < 0)
	    {
		high = mid;
	    }
	    else
	    {
		low = mid + 1;
	    }
	}
	//printf("not found\n");
	return -1;		// not found
    }


unittest
{
    switch (cast(wchar []) "c")
    {
         case "coo":
         default:
             break;
    }
}

