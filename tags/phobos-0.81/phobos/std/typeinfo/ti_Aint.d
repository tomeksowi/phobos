
private import std.string;

// int[]

class TypeInfo_Ai : TypeInfo
{
    uint getHash(void *p)
    {	int[] s = *(int[]*)p;
	uint len = s.length;
	int *str = s;
	uint hash = 0;

	while (len)
	{
	    hash *= 9;
	    hash += *(uint *)str;
	    str++;
	    len--;
	}

	return hash;
    }

    int equals(void *p1, void *p2)
    {
	int[] s1 = *(int[]*)p1;
	int[] s2 = *(int[]*)p2;

	return s1.length == s2.length &&
	       memcmp((void *)s1, (void *)s2, s1.length * int.size) == 0;
    }

    int compare(void *p1, void *p2)
    {
	int[] s1 = *(int[]*)p1;
	int[] s2 = *(int[]*)p2;
	uint len = s1.length;

	if (s2.length < len)
	    len = s2.length;
	for (uint u = 0; u < len; u++)
	{
	    int result = s1[u] - s2[u];
	    if (result)
		return result;
	}
	return cast(int)s1.length - cast(int)s2.length;
    }

    int tsize()
    {
	return (int[]).size;
    }
}
