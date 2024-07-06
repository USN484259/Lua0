# Lua0

Lua with 0-based array indexing


## What is Lua0

**Lua0** is just *Lua 5.3.6*, with the exception that array index starts from **0** instead of **1**

In *Lua* you *can* use nearly anything as "index", so you *can* easily build a 0-based array
by assigning values starting from index 0. However, there are a few problems:
+ Many *Lua* standard libraries only work for 1-based index. such as `table.sort`:
	> table.sort (list [, comp])
	>
	> Sorts list elements in a given order, in-place, from list[1] to list[#list]. If comp is given, then it must be a function that receives two list elements and returns true when the first element must come before the second in the final order (so that, after the sort, i < j implies not comp(list[j],list[i])). If comp is not given, then the standard Lua operator < is used instead.
+ We can *override* the standard libraries with our stubs written in *Lua* to alter the index,
but that is *too expensive*.
+ Some *Lua* core functions also uses 1-based index, such as *Length Operator* and *ipairs*.
So even you *could* easily build 0-based array, you cannot get the correct array length
using `#` operator or iterate correctly using `ipairs`.
+ As *Lua* collects 1-based keys into *array part* of a table to optimize storage and access,
building and using 0-based arrays could impact performance.

**Lua0** overcome *all* above difficulties by making *Lua core* and *Lua standard libraries*
**0-indexed**. See below for details.

## What is 0-based index

If you come from C/C++, you *might* already familiar with this.

+ Array or array-like containers start at index 0, use `a[0]` to access the first element in
the array. For an array of *N* elements, `a[N-1]` is the last element in the array, `a[N]` is
usually invalid and *should not* be accessed (dereferenced).
+ For a range *[first, last)*, the `last` is the **past the end index** and is not included in
the range, number of elements in the range is `last-first`.
	```C
	int a[] = {0, 1, 2, 3};	// int array with 4 elements
	assert(a[0] == 0 && a[1] == 1 && a[2] == 2 && a[3] == 3);
	// a[4];	// array index out of bounds, undefined behavior

	// simple function to find element in int array
	int find(const int *first, const int *last, int val) {
		const int *it;
		for (it = first; it < last; it++) {
			if (*it == val)
				break;
		}
		return it - first;
	}

	assert(find(a, a + 4, 2) == 2);	// found element 2 at index 2
	assert(find(a, a + 4, 4) == 4);	// cannot find element 4
	assert(find(a + 1, a + 4, 0) == 3);	// cannot find element 0 in range [1, 4)
	```
+ In *C++*, for container `a`, `a.end()` gets **past the end iterator** of `a`, which has similiar
effect as **past the end index**. It is common to use **past the end iterator** to specify a range
or indicate the *not found* condition.
	```cxx
	std::string str("Hello World");	// C++ string acts as char-array
	assert(str.length() == 11);
	assert(str[0] == 'H' && str[1] == 'e' && str[6] == 'W' && str[10] == 'd');

	assert(str.begin() + 11 == str.end());	// what is 'past the end iterator'
	std::string substr(str.begin() + 6, str.end());	// create sub-string [6, 11)
	assert(substr == "World");

	assert(std::find(str.begin(), str.end(), 'W') == str.begin() + 6);	// found 'W' at index 6
	assert(std::find(str.begin(), str.end(), 'x') == str.end());	// cannot find 'x'
	```


## What is changed

+ table-initializer place the first non-key element into index 0.
	```lua
	local t = {"a", "b", "c"}
	print(t[0])	-- a
	print(t[1])	-- b
	print(t[2])	-- c
	print(t[3])	-- nil
	```
+ The Length Operator `#` gets the length of *array part* of a *table* starting from index 0.
	```lua
	local t = {[0] = "a", [1] = "b"}
	print(#t)	-- 2
	```
+ array-related optimizations apply to 0-based arrays.
	- *Lua0* will try to collect *table* elements with keys starting from **0** into *array part*

+ All functions taking `table` as parameters assume the *array part* uses 0-based index.

+ `pairs` aka `next` iterate array part from index 0
	- in other words, index 0 is always accessed before index 1 if the table has *array part*.

+ `ipairs` iterate array items from index 0.
	```lua
	local t = {[-4] = "x", [-1] = "y", [0] = "a", [1] = "b", [2] = "c", v = 20}
	for i, v in ipairs(t) do print(i, v) end
	-- 0	a
	-- 1	b
	-- 2	c
	```
+ `select` index arguments from 0.
	```lua
	print(select(0, "a", "b", "c"))		--	a	b	c
	print(select(1, "a", "b", "c"))		--	b	c
	print(select('#', "a", "b", "c"))	--	3
	```
+ `string.sub` `string.byte` takes 0-based index. Note `j` is **past the end index**.
	```lua
	local s = "Hello World"
	print(string.sub(s, 0, 4))	-- Hell
	print(string.sub(s, 6, #t))	-- World
	```
+ `string.find` takes 0-based index, returns 0-based start index and **past the end index**.
	```lua
	local s = "Hello World"
	print(string.find(s, "l+o"))	-- 2	5
	print(string.find(s, 'o', 5))	-- 7	8
	print(string.find(s, 'x'))	-- nil
	```
+ `string.match` takes 0-based index.
	```lua
	local s = "Hello World"
	print(string.match(s, "o.*", 5))	-- orlds
	print(string.match(s, "e+", 2))		-- nil
	```
+ `string.unpack` takes 0-based index.
	```lua
	local s = "Hello" + string.pack("=iii", 1, 2, 3)
	print(#s)	-- 17
	print(string.unpack("=iii", s, 5))	-- 1	2	3	17
	```
+ Pattern special capture `()` returns 0-based index
	```lua
	local s = "Hello World"
	print(string.match(s, "()ll()"))	-- 2	4
	```
+ `table.insert` `table.remove` takes 0-based index.
	```lua
	local t = {"a"}
	table.insert(t, 0, "b")
	print(t[0], t[1])	--	b	a
	print(table.remove(t, 1))	-- a
	print(t[0])	-- b
	```
+ `table.concat` `table.unpack` takes 0-based index. Note `j` is **past the end index**.
	```lua
	local t = {"a", "b", "c", "d"}
	print(table.concat(t, ',', 1, 3))	-- b,c,
	print(table.unpack(t, 2, #t))	--	c	d
	```
+ `table.pack` produces list with 0-based index.
	```lua
	local t = table.pack("a", "b", "c", "d")
	for i, v in ipairs(t) do print(i, v) end
	-- 0	a
	-- 1	b
	-- 2	c
	-- 3	d
	```
+ `table.move` takes 0-based index. Note `e` is **past the end index**.
	```lua
	local t = {"a", "b", "c", "d"}
	table.move(t, 2, #t, 0)
	for i, v in ipairs(t) do print(i, v) end
	-- 0	c
	-- 1	d
	-- 2	c
	-- 3	d
	```
+ `table.sort` sorts objects in range *[0, #list-1]*.
	```lua
	local t = {4, 8, 4, 2, 5, 9}
	table.sort(t)
	for i, v in ipairs(t) do print(i, v) end
	-- 0	2
	-- 1	4
	-- 2	4
	-- 3	5
	-- 4	8
	-- 5	9
	```
+ `utf8.codes` generates 0-based index.
	```lua
	for p, c in utf8.codes("汉字") do print(p, c) end
	-- 0	27721
	-- 3	23383
	```
+ `utf8.codepoint` `utf8.len` takes 0-based index. Note `j` is **past the end index**.
	```lua
	local s = "Hello汉字"
	print(utf8.len(s, 5))	-- 2
	print(utf8.codepoint(s, 5, 8))	-- 27721
	```
+ `utf8.offset` takes 0-based index, returns 0-based index. Note the meaning of `n` is **not changed**.
	```lua
	local s = "汉字"
	print(utf8.offset(s, -1, 3))	-- 0
	print(utf8.offset(s, 0, 4))	-- 3
	```
+ `debug.getlocal` `debug.setlocal` takes 0-based index of locals. Note the meaning of `level` is unchanged.
	```lua
	local a, b = 0, 1
	debug.getlocal(1, 0)	-- a	0
	debug.setlocal(1, 1, 4)
	print(a, b)	-- 0	4
	```
+ `debug.getupvalue` `debug.setupvalue` takes 0-based index.
	```lua
	local a, b = 0, 1
	local function foo() a = b + 1 end
	print(debug.getupvalue(foo, 0))	-- a	0
	debug.setupvalue(foo, 1, 4)
	foo(); print(a, b)	-- 5	4
	```
+ `debug.upvalueid` `debug.upvaluejoin` takes 0-based index.
	```lua
	local a, b, c = 0, 1, 2
	local function foo() a = b + 1 end
	local function bar() c = a + 1 end
	debug.upvaluejoin(foo, 1, bar, 0)
	foo(); print(a, b, c)	-- 3	1	2
	```


## What is ***not*** changed

+ All negative indices are unaffected, counting from the end. Since *string* and *table* libraries
now use **past the end index**, you cannot use `-1` to specify *end of string or list*, use `#t` instead.

+ Numerical `for` is **not** changed. It could be more confusing if *limit* were **past the end index**.
Numerical `for` work perfectly for number counting. For array iterating, use `for i=0,#t-1 do`, or use `ipairs`

+ Pattern matching `%n`, n still between 1 and 9.

+ Parameter `n` in `utf8.offset` is unchanged since `n=0` already has its meaning.
Note parameter `i` and return value are 0-based.

+ `level` parameters in `debug` library is unchanged, since *level 0* points to the library function
being called.

+ The *stack index* widely used in *C API* is **unchanged** since this is how the underlying *stack*
is implemented. Somewhat similiar to *call stack* in *C* (aka *ABI* on most platforms), index 0 of
the *stack frame* is the function being called, stack space local to the function starts at index 1.

## Compatibility with ***Lua***

+ Since the *only* thing changed is the *index*, everything else *should* be the same as *Lua*.
+ You *can* adapt existing *Lua* code by changing *every* use of index. Depending on code complexity
and *line-of-code* this *could* be time-consuming and/or error-prone.
+ The implicitly indices in *table-initializer* chould be inobvious.
+ 3rd party *Lua* or *C* libraries may assume 1-based indexing and become incompatible.
+ Compiled binary chunks *can* be loaded, but have the same status as text chunks, except that
you cannot *easily* modify them.
+ It *should* be *easier* to port **0-based index** code (namely *C* or *Python*) to **Lua0**

## Known issues and TODO

+ since *string* and *table* libraries use **past the end index**, there is a corner case that it is
impossible to include element at index `math.maxinteger`, since the **past the end index** would be
`math.maxinteger+1` which overflow and became `math.mininteger`. This *should* only affect *table*
library since it is *impractical* to make a *string* of **2^63** bytes.

+ TODO: *testC* related tests has not been reviewed
+ TODO: *C API* has not been reviewed
+ TODO: change interpreter name and file extension to *lua0* to emphasize the *incompatibility* with *Lua*


## Why this project exist

- Contents in this section are all *my* (USN484259) preferences. You *may* or *may not* agree with me.

*Lua* is a *fantastic* programming language:
+ It's simple: nil, boolean, number, string, function, table, userdata, coroutine, nothing else.
+ It's powerful: you can make classes, inheritance, polymorphism just from *tables* and `setmetatable`.
+ It's fast: *Lua* is one of the fastest interpreted scripting languages in production.
+ It's embedded: *Lua* is implemented in pure C, with some standard libs calling POSIX procedures.
It can be embeded into other programs or ported to nearly *every* platform with ease.
+ It's scalable: very simple C API to access *Lua* values as well as register C data structures
and functions to *Lua*. *C* program with *Lua* libraries or *Lua* program with *C* libraries, at your option.

However, *Lua* is not *perfect*:
+ restricted syntax: many convenient syntax sugars are absent in *Lua*, like `continue` and `+=` `-=`.
Maybe these are not trivial to implement in a single-pass parser.
+ limited standard libraries: this *should* be a good thing if you're embedding *Lua* or
porting *Lua* to embedded platforms. But for general *Desktop* usage, it's not enough.
However, since *Lua* is *scalable*, there are thousands of 3rd-party libraries to fill the gap.
+ **1-based indexing**: nearly *everything* in *Lua* is 1-indexed. This may came from
the long history of *Lua*, but as a result, it's *weird*.

I *really* love *Lua*, but not the part of **1-based indexing**. I'm from the world of *C* and *Assembly*,
where array index *must* start from 0 due to how processor/memory works. Whenever I access arrays,
(reverse) iterate over arrays, or do complex maths on array indices in *Lua*, I have to deal with
the weird +1 index and/or len-1 last-index, which is really a headache.

*What if Lua had been designed with array index starting from 0 ?*
This is why this project come into being: change *everything* related to indexing, leave the rest as is.

## Origin

**Lua0** original source code is from these projects:
+ [lua-5.3.6](https://www.lua.org/manual/5.3/readme.html)
+ [lua-5.3.4-tests](https://www.lua.org/tests/)

