
// Copyright (C) 2001-2003 by Digital Mars
// All Rights Reserved
// Written by Walter Bright
// www.digitalmars.com

// GC tester program

import std.c.stdio;
import std.c.stdlib;
import std.string;

import gcstats;
import std.gc;
import gcx;
import std.random;

void printStats(GC *gc)
{
    GCStats stats;

    //gc.getStats(stats);
    printf("poolsize = x%x, usedsize = x%x, freelistsize = x%x, freeblocks = %d, pageblocks = %d\n",
	stats.poolsize, stats.usedsize, stats.freelistsize, stats.freeblocks, stats.pageblocks);
}

uint PERMUTE(uint key)
{
    return key + 1;
}

void fill(void *p, uint key, uint size)
{
    uint i;
    byte *q = cast(byte *)p;

    for (i = 0; i < size; i++)
    {
	key = PERMUTE(key);
	q[i] = cast(byte)key;
    }
}

void verify(void *p, uint key, uint size)
{
    uint i;
    byte *q = cast(byte *)p;

    for (i = 0; i < size; i++)
    {
	key = PERMUTE(key);
	assert(q[i] == cast(byte)key);
    }
}

long desregs()
{
    return strlen("foo");
}

/* ---------------------------- */

void smoke()
{
    GC *gc;

    printf("--------------------------smoke()\n");

    gc = newGC();
    deleteGC(gc);
printf("smoke.1\n");

    gc = newGC();
    gc.initialize();
    deleteGC(gc);
printf("smoke.2\n");

    gc = newGC();
    gc.initialize();
    char *p = cast(char *)gc.malloc(10);
    assert(p);
    strcpy(p, "Hello!");
//    char *p2 = gc.strdup(p);
//    printf("p2 = %x, '%s'\n", p2, p2);
//    int result = strcmp(p, p2);
//    assert(result == 0);
//    gc.strdup(p);

    printf("p  = %x\n", p);
    p = null;
    gc.fullCollect();
    printStats(gc);

    deleteGC(gc);
}

/* ---------------------------- */

void finalizer(void *p, void *dummy)
{
}

void smoke2()
{
    GC *gc;
    int *p;
    int i;

    const int SMOKE2_SIZE = 100;
    int *foo[SMOKE2_SIZE];

    printf("--------------------------smoke2()\n");

    gc = newGC();
    gc.initialize();

    for (i = 0; i < SMOKE2_SIZE; i++)
    {
	p = cast(int *)gc.calloc(i + 1, 500);
	p[0] = i * 3;
	foo[i] = p;
	gc.setFinalizer(cast(void *)p, &finalizer);
    }

    for (i = 0; i < SMOKE2_SIZE; i += 2)
    {
	p = foo[i];
	if (p[0] != i * 3)
	{
	    printf("p = %x, i = %d, p[0] = %d\n", p, i, p[0]);
	    //c.stdio.fflush(stdout);
	}
	assert(p[0] == i * 3);
	gc.free(p);
    }

    p = null;
    foo[] = null;

    gc.fullCollect();
    printStats(gc);

    deleteGC(gc);
}

/* ---------------------------- */

void smoke3()
{
    GC *gc;
    int *p;
    int i;

    printf("--------------------------smoke3()\n");

    gc = newGC();
    gc.initialize();

//    for (i = 0; i < 1000000; i++)
    for (i = 0; i < 1000; i++)
    {
	uint size = std.random.rand() % 2048;
	p = cast(int *)gc.malloc(size);
	memset(p, i, size);

	size = std.random.rand() % 2048;
	p = cast(int *)gc.realloc(p, size);
	memset(p, i + 1, size);
    }

    p = null;
    desregs();
    gc.fullCollect();
    printStats(gc);

    deleteGC(gc);
}

/* ---------------------------- */

void smoke4()
{
    GC *gc;
    int *p;
    int i;

    printf("--------------------------smoke4()\n");

    gc = newGC();
    gc.initialize();

    for (i = 0; i < 80000; i++)
    {
	uint size = i;
	p = cast(int *)gc.malloc(size);
	memset(p, i, size);

	size = std.random.rand() % 2048;
	gc.check(p);
	p = cast(int *)gc.realloc(p, size);
	memset(p, i + 1, size);
    }

    p = null;
    desregs();
    gc.fullCollect();
    printStats(gc);

    deleteGC(gc);
}

/* ---------------------------- */

void smoke5(GC *gc)
{
    byte *p;
    int i;
    int j;
    const int SMOKE5_SIZE = 1000;
    byte *array[SMOKE5_SIZE];
    uint offset[SMOKE5_SIZE];

    printf("--------------------------smoke5()\n");
    //printf("gc = %p\n", gc);
    //printf("gc = %p, gcx = %p, self = %x\n", gc, gc.gcx, gc.gcx.self);

    for (j = 0; j < 20; j++)
    {
	for (i = 0; i < 2000 /*4000*/; i++)
	{
	    uint size = (std.random.rand() % 2048) + 1;
	    uint index = std.random.rand() % SMOKE5_SIZE;

	    //printf("index = %d, size = %d\n", index, size);
	    p = array[index] - offset[index];
	    p = cast(byte *)gc.realloc(p, size);
	    if (array[index])
	    {	uint s;

		//printf("\tverify = %d\n", p[0]);
		s = offset[index];
		if (size < s)
		    s = size;
		verify(p, index, s);
	    }
	    array[index] = p;
	    fill(p, index, size);
	    offset[index] = std.random.rand() % size;
	    array[index] += offset[index];

	    //printf("p[0] = %d\n", p[0]);
	}
	gc.fullCollect();
    }

    p = null;
    array[] = null;
    gc.fullCollect();
    printStats(gc);
}

/* ---------------------------- */

void test1()
{
    printf("test1()\n");
    char[] a=new char[0];
    uint c = 200000;
    while (c--)
	a ~= 'x';
    //printf("a = '%.*s'\n", a);
    printf("test1() done\n");
}

/* ---------------------------- */

int main(char[][] args)
{
    test1();

    GC *gc;

    printf("GC test start\n");

    gc = newGC();
printf("gc = %p\n", gc);
    gc.initialize();

    smoke();
    smoke2();
    smoke3();
    smoke4();
printf("gc = %p\n", gc);
    smoke5(gc);

    deleteGC(gc);

    printf("GC test success\n");
    return EXIT_SUCCESS;
}

GC *newGC()
{
    return cast(GC *)std.c.stdlib.calloc(1, GC.size);
}

void deleteGC(GC *gc)
{
    gc.Dtor();
    std.c.stdlib.free(gc);
}