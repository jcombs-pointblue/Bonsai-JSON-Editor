import SwiftUI

/// Comprehensive jq syntax reference with examples for every supported feature
struct JQReferenceSection: View {
    var body: some View {
        HelpSectionHeader(title: "jq Reference", icon: "function")

        HelpParagraph("Bonsai includes a built-in jq query engine that supports a broad subset of the jq language. This reference documents every supported filter, operator, and built-in function with examples.")

        HelpParagraph("In the examples below, \"Input\" shows the JSON being queried and \"Output\" shows what the expression produces.")

        // MARK: - Basic Filters
        Group {
            JQCategory("Basic Filters")

            JQEntry(
                name: "Identity: .",
                description: "Returns the input unchanged. The simplest possible filter.",
                examples: [
                    JQExample(input: "{\"name\": \"Bonsai\"}", expression: ".", output: "{\"name\": \"Bonsai\"}")
                ]
            )

            JQEntry(
                name: "Field Access: .foo",
                description: "Accesses a field of an object by name. Returns null if the field doesn't exist.",
                examples: [
                    JQExample(input: "{\"name\": \"Alice\", \"age\": 30}", expression: ".name", output: "\"Alice\""),
                    JQExample(input: "{\"name\": \"Alice\"}", expression: ".missing", output: "null")
                ]
            )

            JQEntry(
                name: "Nested Field Access: .foo.bar",
                description: "Chain field accesses with dots to reach nested values.",
                examples: [
                    JQExample(input: "{\"user\": {\"name\": \"Alice\"}}", expression: ".user.name", output: "\"Alice\"")
                ]
            )

            JQEntry(
                name: "Optional Field Access: .foo?",
                description: "Like .foo but suppresses errors when the input is not an object. Returns nothing instead of an error.",
                examples: [
                    JQExample(input: "42", expression: ".name?", output: "(no output)")
                ]
            )

            JQEntry(
                name: "Array Index: .[n]",
                description: "Gets the nth element of an array (zero-based). Negative indices count from the end.",
                examples: [
                    JQExample(input: "[10, 20, 30]", expression: ".[1]", output: "20"),
                    JQExample(input: "[10, 20, 30]", expression: ".[-1]", output: "30")
                ]
            )

            JQEntry(
                name: "Array Slice: .[m:n]",
                description: "Returns a subarray from index m (inclusive) to n (exclusive).",
                examples: [
                    JQExample(input: "[0, 1, 2, 3, 4]", expression: ".[2:4]", output: "[2, 3]"),
                    JQExample(input: "[0, 1, 2, 3, 4]", expression: ".[:3]", output: "[0, 1, 2]")
                ]
            )

            JQEntry(
                name: "Iterator: .[]",
                description: "Produces each element of an array or each value of an object as separate outputs.",
                examples: [
                    JQExample(input: "[1, 2, 3]", expression: ".[]", output: "1\n2\n3"),
                    JQExample(input: "{\"a\": 1, \"b\": 2}", expression: ".[]", output: "1\n2")
                ]
            )

            JQEntry(
                name: "Optional Iterator: .[]?",
                description: "Like .[] but suppresses errors for non-iterable inputs.",
                examples: [
                    JQExample(input: "42", expression: ".[]?", output: "(no output)")
                ]
            )

            JQEntry(
                name: "Recursive Descent: ..",
                description: "Recursively produces every value in the input at all depths.",
                examples: [
                    JQExample(input: "{\"a\": {\"b\": 1}}", expression: ".. | numbers", output: "1")
                ]
            )
        }

        // MARK: - Pipes and Composition
        Group {
            JQCategory("Pipes & Composition")

            JQEntry(
                name: "Pipe: |",
                description: "Feeds the output of the left expression into the right expression. This is the primary composition operator in jq. Each output of the left side is processed independently by the right side.",
                examples: [
                    JQExample(input: "{\"users\": [{\"name\": \"Alice\"}, {\"name\": \"Bob\"}]}", expression: ".users | .[0]", output: "{\"name\": \"Alice\"}"),
                    JQExample(input: "{\"users\": [{\"name\": \"Alice\"}, {\"name\": \"Bob\"}]}", expression: ".users[] | .name", output: "\"Alice\"\n\"Bob\"")
                ]
            )

            JQEntry(
                name: "Comma: ,",
                description: "Produces multiple outputs. Both the left and right expressions are evaluated against the same input, and all outputs are concatenated.",
                examples: [
                    JQExample(input: "{\"a\": 1, \"b\": 2}", expression: ".a, .b", output: "1\n2"),
                    JQExample(input: "null", expression: "1, 2, 3", output: "1\n2\n3")
                ]
            )
        }

        // MARK: - Types and Values
        Group {
            JQCategory("Types & Literals")

            JQEntry(
                name: "Null",
                description: "The null literal.",
                examples: [
                    JQExample(input: "42", expression: "null", output: "null")
                ]
            )

            JQEntry(
                name: "Booleans",
                description: "true and false literals. In jq, false and null are \"falsy\"; everything else is \"truthy\".",
                examples: [
                    JQExample(input: "null", expression: "true", output: "true"),
                    JQExample(input: "null", expression: "null | not", output: "true")
                ]
            )

            JQEntry(
                name: "Numbers",
                description: "Integer and floating-point numeric literals.",
                examples: [
                    JQExample(input: "null", expression: "42", output: "42"),
                    JQExample(input: "null", expression: "3.14", output: "3.14")
                ]
            )

            JQEntry(
                name: "Strings",
                description: "Double-quoted string literals with standard escape sequences.",
                examples: [
                    JQExample(input: "null", expression: "\"hello world\"", output: "\"hello world\"")
                ]
            )

            JQEntry(
                name: "Arrays",
                description: "Construct arrays using [expr]. The expression inside is evaluated and all outputs are collected into a single array.",
                examples: [
                    JQExample(input: "{\"a\": 1, \"b\": 2}", expression: "[.a, .b]", output: "[1, 2]"),
                    JQExample(input: "null", expression: "[range(5)]", output: "[0, 1, 2, 3, 4]"),
                    JQExample(input: "null", expression: "[]", output: "[]")
                ]
            )

            JQEntry(
                name: "Objects",
                description: "Construct objects using {key: expr}. Keys can be identifiers, strings, or expressions in parentheses. Shorthand {foo} is equivalent to {foo: .foo}.",
                examples: [
                    JQExample(input: "{\"name\": \"Alice\", \"age\": 30}", expression: "{name: .name, years: .age}", output: "{\"name\": \"Alice\", \"years\": 30}"),
                    JQExample(input: "{\"name\": \"Alice\", \"age\": 30}", expression: "{name, age}", output: "{\"name\": \"Alice\", \"age\": 30}")
                ]
            )
        }

        // MARK: - Comparison and Logic
        Group {
            JQCategory("Comparison & Logic")

            JQEntry(
                name: "Equality: ==, !=",
                description: "Test whether two values are equal or not equal. Works on all types including nested objects and arrays.",
                examples: [
                    JQExample(input: "{\"a\": 1}", expression: ".a == 1", output: "true"),
                    JQExample(input: "{\"a\": 1}", expression: ".a != 2", output: "true")
                ]
            )

            JQEntry(
                name: "Ordering: <, <=, >, >=",
                description: "Compare values. Numbers are compared numerically, strings lexicographically.",
                examples: [
                    JQExample(input: "null", expression: "5 > 3", output: "true"),
                    JQExample(input: "null", expression: "\"apple\" < \"banana\"", output: "true")
                ]
            )

            JQEntry(
                name: "Logical: and, or, not",
                description: "Boolean logic operators. Remember: false and null are falsy, everything else is truthy. not is a postfix filter.",
                examples: [
                    JQExample(input: "null", expression: "true and false", output: "false"),
                    JQExample(input: "null", expression: "false or true", output: "true"),
                    JQExample(input: "null", expression: "true | not", output: "false"),
                    JQExample(input: "null", expression: "null | not", output: "true")
                ]
            )
        }

        // MARK: - Arithmetic
        Group {
            JQCategory("Arithmetic")

            JQEntry(
                name: "Operators: +, -, *, /, %",
                description: "Standard arithmetic on numbers. The + operator also concatenates strings, merges objects, and concatenates arrays.",
                examples: [
                    JQExample(input: "null", expression: "2 + 3", output: "5"),
                    JQExample(input: "null", expression: "10 / 3", output: "3.3333333333333335"),
                    JQExample(input: "null", expression: "10 % 3", output: "1"),
                    JQExample(input: "null", expression: "\"hello \" + \"world\"", output: "\"hello world\""),
                    JQExample(input: "null", expression: "[1, 2] + [3]", output: "[1, 2, 3]"),
                    JQExample(input: "null", expression: "{\"a\": 1} + {\"b\": 2}", output: "{\"a\": 1, \"b\": 2}")
                ]
            )

            JQEntry(
                name: "Negation: -expr",
                description: "Negates a numeric value.",
                examples: [
                    JQExample(input: "{\"x\": 5}", expression: "-(. x)", output: "-5")
                ]
            )
        }

        // MARK: - Conditionals and Control Flow
        Group {
            JQCategory("Conditionals & Control Flow")

            JQEntry(
                name: "If-Then-Else",
                description: "Conditional expression. The else clause is optional; without it, the input passes through unchanged when the condition is false.",
                examples: [
                    JQExample(input: "5", expression: "if . > 3 then \"big\" else \"small\" end", output: "\"big\""),
                    JQExample(input: "2", expression: "if . > 3 then \"big\" else \"small\" end", output: "\"small\"")
                ]
            )

            JQEntry(
                name: "Try-Catch",
                description: "Catches errors from the try expression. Without catch, errors are silently suppressed.",
                examples: [
                    JQExample(input: "\"not a number\"", expression: "try tonumber", output: "(no output)"),
                    JQExample(input: "\"not a number\"", expression: "try tonumber catch \"invalid\"", output: "\"invalid\"")
                ]
            )
        }

        // MARK: - Selection and Filtering
        Group {
            JQCategory("Selection & Filtering")

            JQEntry(
                name: "select(expr)",
                description: "Passes through the input unchanged if expr returns a truthy value; otherwise produces no output. Essential for filtering arrays.",
                examples: [
                    JQExample(input: "[1, 2, 3, 4, 5]", expression: "[.[] | select(. > 3)]", output: "[4, 5]"),
                    JQExample(input: "[{\"name\": \"Alice\", \"age\": 30}, {\"name\": \"Bob\", \"age\": 17}]", expression: ".[] | select(.age >= 18) | .name", output: "\"Alice\"")
                ]
            )

            JQEntry(
                name: "empty",
                description: "Produces no output. Useful for conditionally suppressing results.",
                examples: [
                    JQExample(input: "null", expression: "1, empty, 2", output: "1\n2")
                ]
            )

            JQEntry(
                name: "Type Selectors",
                description: "Filter values by type. Each produces its input if it matches the type, or nothing otherwise: objects, arrays, strings, numbers, booleans, nulls, iterables, scalars.",
                examples: [
                    JQExample(input: "[1, \"two\", true, null, [3]]", expression: "[.[] | strings]", output: "[\"two\"]"),
                    JQExample(input: "[1, \"two\", true, null, [3]]", expression: "[.[] | scalars]", output: "[1, \"two\", true, null]")
                ]
            )
        }

        // MARK: - String Functions
        Group {
            JQCategory("String Functions")

            JQEntry(
                name: "ascii_downcase, ascii_upcase",
                description: "Convert string to lowercase or uppercase.",
                examples: [
                    JQExample(input: "\"Hello World\"", expression: "ascii_downcase", output: "\"hello world\""),
                    JQExample(input: "\"Hello World\"", expression: "ascii_upcase", output: "\"HELLO WORLD\"")
                ]
            )

            JQEntry(
                name: "split(sep)",
                description: "Splits a string by the separator into an array of substrings.",
                examples: [
                    JQExample(input: "\"a,b,c\"", expression: "split(\",\")", output: "[\"a\", \"b\", \"c\"]")
                ]
            )

            JQEntry(
                name: "join(sep)",
                description: "Joins an array of strings (or mixed types) with the separator.",
                examples: [
                    JQExample(input: "[\"a\", \"b\", \"c\"]", expression: "join(\"-\")", output: "\"a-b-c\"")
                ]
            )

            JQEntry(
                name: "startswith(str), endswith(str)",
                description: "Tests whether a string starts or ends with the given substring.",
                examples: [
                    JQExample(input: "\"hello world\"", expression: "startswith(\"hello\")", output: "true"),
                    JQExample(input: "\"hello world\"", expression: "endswith(\"world\")", output: "true")
                ]
            )

            JQEntry(
                name: "ltrimstr(str), rtrimstr(str)",
                description: "Removes a prefix or suffix from a string if present.",
                examples: [
                    JQExample(input: "\"hello world\"", expression: "ltrimstr(\"hello \")", output: "\"world\""),
                    JQExample(input: "\"file.json\"", expression: "rtrimstr(\".json\")", output: "\"file\"")
                ]
            )

            JQEntry(
                name: "test(regex)",
                description: "Tests whether the string matches the regular expression. Returns true/false.",
                examples: [
                    JQExample(input: "\"foo123\"", expression: "test(\"[0-9]+\")", output: "true"),
                    JQExample(input: "\"foobar\"", expression: "test(\"^foo\")", output: "true")
                ]
            )

            JQEntry(
                name: "match(regex)",
                description: "Returns the first match of the regex as an object with offset, length, string, and captures.",
                examples: [
                    JQExample(input: "\"foo bar\"", expression: "match(\"(foo) (bar)\") | .captures | map(.string)", output: "[\"foo\", \"bar\"]")
                ]
            )

            JQEntry(
                name: "scan(regex)",
                description: "Returns all non-overlapping matches of the regex. Each match is an array of capture groups.",
                examples: [
                    JQExample(input: "\"test 123 hello 456\"", expression: "[scan(\"[0-9]+\")]", output: "[[\"123\"], [\"456\"]]")
                ]
            )

            JQEntry(
                name: "sub(regex; replacement), gsub(regex; replacement)",
                description: "Replace the first match (sub) or all matches (gsub) of a regex.",
                examples: [
                    JQExample(input: "\"hello world\"", expression: "gsub(\"o\"; \"0\")", output: "\"hell0 w0rld\"")
                ]
            )

            JQEntry(
                name: "explode, implode",
                description: "explode converts a string to an array of Unicode codepoints. implode converts back.",
                examples: [
                    JQExample(input: "\"AB\"", expression: "explode", output: "[65, 66]"),
                    JQExample(input: "[72, 105]", expression: "implode", output: "\"Hi\"")
                ]
            )

            JQEntry(
                name: "indices(str), index(str), rindex(str)",
                description: "Find positions of a substring. indices returns all positions, index the first, rindex the last.",
                examples: [
                    JQExample(input: "\"abcabc\"", expression: "indices(\"bc\")", output: "[1, 4]"),
                    JQExample(input: "\"abcabc\"", expression: "index(\"bc\")", output: "1"),
                    JQExample(input: "\"abcabc\"", expression: "rindex(\"bc\")", output: "4")
                ]
            )
        }

        // MARK: - Array Functions
        Group {
            JQCategory("Array Functions")

            JQEntry(
                name: "map(expr)",
                description: "Apply an expression to every element of an array and collect the results. Equivalent to [.[] | expr]. Elements where the expression produces empty (e.g., via select) are silently skipped.",
                examples: [
                    JQExample(input: "[1, 2, 3]", expression: "map(. * 2)", output: "[2, 4, 6]"),
                    JQExample(input: "[1, 2, 3, 4, 5]", expression: "map(select(. > 3))", output: "[4, 5]")
                ]
            )

            JQEntry(
                name: "sort, sort_by(expr)",
                description: "Sorts an array. sort uses natural ordering; sort_by sorts by a derived key.",
                examples: [
                    JQExample(input: "[3, 1, 2]", expression: "sort", output: "[1, 2, 3]"),
                    JQExample(input: "[{\"name\": \"Charlie\"}, {\"name\": \"Alice\"}]", expression: "sort_by(.name)", output: "[{\"name\": \"Alice\"}, {\"name\": \"Charlie\"}]")
                ]
            )

            JQEntry(
                name: "reverse",
                description: "Reverses an array or a string.",
                examples: [
                    JQExample(input: "[1, 2, 3]", expression: "reverse", output: "[3, 2, 1]"),
                    JQExample(input: "\"hello\"", expression: "reverse", output: "\"olleh\"")
                ]
            )

            JQEntry(
                name: "unique, unique_by(expr)",
                description: "Removes duplicates from an array. unique_by deduplicates based on a derived key.",
                examples: [
                    JQExample(input: "[1, 2, 1, 3, 2]", expression: "unique", output: "[1, 2, 3]"),
                    JQExample(input: "[{\"id\": 1, \"v\": \"a\"}, {\"id\": 1, \"v\": \"b\"}, {\"id\": 2, \"v\": \"c\"}]", expression: "unique_by(.id)", output: "[{\"id\": 1, \"v\": \"a\"}, {\"id\": 2, \"v\": \"c\"}]")
                ]
            )

            JQEntry(
                name: "group_by(expr)",
                description: "Groups array elements by a derived key. Returns an array of arrays.",
                examples: [
                    JQExample(input: "[{\"type\": \"a\", \"v\": 1}, {\"type\": \"b\", \"v\": 2}, {\"type\": \"a\", \"v\": 3}]", expression: "group_by(.type)", output: "[[{\"type\": \"a\", \"v\": 1}, {\"type\": \"a\", \"v\": 3}], [{\"type\": \"b\", \"v\": 2}]]")
                ]
            )

            JQEntry(
                name: "flatten, flatten(depth)",
                description: "Flattens nested arrays. Optional depth argument limits how many levels to flatten (default 1).",
                examples: [
                    JQExample(input: "[[1, 2], [3, [4, 5]]]", expression: "flatten", output: "[1, 2, 3, [4, 5]]"),
                    JQExample(input: "[[1, [2]], [3, [4]]]", expression: "flatten(2)", output: "[1, 2, 3, 4]")
                ]
            )

            JQEntry(
                name: "add",
                description: "Reduces an array by combining elements with +. Works with numbers (sum), strings (concatenation), arrays (flattening one level), and objects (merging).",
                examples: [
                    JQExample(input: "[1, 2, 3]", expression: "add", output: "6"),
                    JQExample(input: "[\"a\", \"b\", \"c\"]", expression: "add", output: "\"abc\""),
                    JQExample(input: "[[1], [2], [3]]", expression: "add", output: "[1, 2, 3]"),
                    JQExample(input: "[{\"a\": 1}, {\"b\": 2}]", expression: "add", output: "{\"a\": 1, \"b\": 2}")
                ]
            )

            JQEntry(
                name: "any, any(expr), all, all(expr)",
                description: "Test whether any or all elements of an array satisfy a condition. Without an argument, tests truthiness directly.",
                examples: [
                    JQExample(input: "[1, 2, 3]", expression: "any(. > 2)", output: "true"),
                    JQExample(input: "[1, 2, 3]", expression: "all(. > 0)", output: "true"),
                    JQExample(input: "[true, false, true]", expression: "any", output: "true"),
                    JQExample(input: "[true, false, true]", expression: "all", output: "false")
                ]
            )

            JQEntry(
                name: "min, max, min_by(expr), max_by(expr)",
                description: "Find minimum or maximum values. The _by variants compare by a derived key.",
                examples: [
                    JQExample(input: "[3, 1, 2]", expression: "min", output: "1"),
                    JQExample(input: "[3, 1, 2]", expression: "max", output: "3"),
                    JQExample(input: "[{\"name\": \"Alice\", \"age\": 30}, {\"name\": \"Bob\", \"age\": 25}]", expression: "min_by(.age) | .name", output: "\"Bob\"")
                ]
            )

            JQEntry(
                name: "first, first(expr), last, last(expr)",
                description: "Returns the first or last element of an array, or the first/last output of an expression.",
                examples: [
                    JQExample(input: "[10, 20, 30]", expression: "first", output: "10"),
                    JQExample(input: "[10, 20, 30]", expression: "last", output: "30"),
                    JQExample(input: "null", expression: "first(range(5))", output: "0")
                ]
            )

            JQEntry(
                name: "transpose",
                description: "Transposes an array of arrays (swaps rows and columns).",
                examples: [
                    JQExample(input: "[[1, 2], [3, 4]]", expression: "transpose", output: "[[1, 3], [2, 4]]")
                ]
            )

            JQEntry(
                name: "range(n), range(m; n)",
                description: "Generates a sequence of numbers. range(n) produces 0 to n-1. range(m; n) produces m to n-1.",
                examples: [
                    JQExample(input: "null", expression: "[range(4)]", output: "[0, 1, 2, 3]"),
                    JQExample(input: "null", expression: "[range(2; 5)]", output: "[2, 3, 4]")
                ]
            )

            JQEntry(
                name: "limit(n; expr)",
                description: "Takes at most n outputs from an expression.",
                examples: [
                    JQExample(input: "null", expression: "[limit(3; range(10))]", output: "[0, 1, 2]")
                ]
            )

            JQEntry(
                name: "nth(n; expr)",
                description: "Returns the nth output of an expression (zero-based).",
                examples: [
                    JQExample(input: "null", expression: "nth(2; range(10))", output: "2")
                ]
            )
        }

        // MARK: - Object Functions
        Group {
            JQCategory("Object Functions")

            JQEntry(
                name: "keys, keys_unsorted",
                description: "Returns an array of the object's keys. keys sorts them alphabetically; keys_unsorted preserves the original order.",
                examples: [
                    JQExample(input: "{\"b\": 2, \"a\": 1, \"c\": 3}", expression: "keys", output: "[\"a\", \"b\", \"c\"]"),
                    JQExample(input: "{\"b\": 2, \"a\": 1, \"c\": 3}", expression: "keys_unsorted", output: "[\"b\", \"a\", \"c\"]")
                ]
            )

            JQEntry(
                name: "values",
                description: "Returns an array of the object's values in key order.",
                examples: [
                    JQExample(input: "{\"a\": 1, \"b\": 2}", expression: "values", output: "[1, 2]")
                ]
            )

            JQEntry(
                name: "has(key)",
                description: "Tests whether an object has the given key, or an array has the given index.",
                examples: [
                    JQExample(input: "{\"name\": \"Alice\"}", expression: "has(\"name\")", output: "true"),
                    JQExample(input: "{\"name\": \"Alice\"}", expression: "has(\"age\")", output: "false"),
                    JQExample(input: "[1, 2, 3]", expression: "has(1)", output: "true")
                ]
            )

            JQEntry(
                name: "in(expr)",
                description: "Tests whether the input (a key or index) exists in the given object or array.",
                examples: [
                    JQExample(input: "\"name\"", expression: "in({\"name\": \"Alice\"})", output: "true")
                ]
            )

            JQEntry(
                name: "contains(other)",
                description: "Tests whether the input contains the other value. For objects, checks that all key-value pairs in other exist. For arrays, checks that all elements are present. For strings, checks for substring containment.",
                examples: [
                    JQExample(input: "{\"a\": 1, \"b\": 2}", expression: "contains({\"a\": 1})", output: "true"),
                    JQExample(input: "[1, 2, 3]", expression: "contains([2, 3])", output: "true"),
                    JQExample(input: "\"foobar\"", expression: "contains(\"foo\")", output: "true")
                ]
            )

            JQEntry(
                name: "inside(other)",
                description: "The inverse of contains. Tests whether the input is contained within other.",
                examples: [
                    JQExample(input: "{\"a\": 1}", expression: "inside({\"a\": 1, \"b\": 2})", output: "true")
                ]
            )

            JQEntry(
                name: "to_entries",
                description: "Converts an object to an array of {key, value} objects.",
                examples: [
                    JQExample(input: "{\"a\": 1, \"b\": 2}", expression: "to_entries", output: "[{\"key\": \"a\", \"value\": 1}, {\"key\": \"b\", \"value\": 2}]")
                ]
            )

            JQEntry(
                name: "from_entries",
                description: "Converts an array of {key, value} objects back into an object.",
                examples: [
                    JQExample(input: "[{\"key\": \"a\", \"value\": 1}, {\"key\": \"b\", \"value\": 2}]", expression: "from_entries", output: "{\"a\": 1, \"b\": 2}")
                ]
            )

            JQEntry(
                name: "with_entries(expr)",
                description: "Shorthand for to_entries | map(expr) | from_entries. Transform an object's key-value pairs.",
                examples: [
                    JQExample(input: "{\"a\": 1, \"b\": 2}", expression: "with_entries(.value += 10)", output: "{\"a\": 11, \"b\": 12}"),
                    JQExample(input: "{\"FOO\": 1, \"BAR\": 2}", expression: "with_entries(.key |= ascii_downcase)", output: "{\"foo\": 1, \"bar\": 2}")
                ]
            )

            JQEntry(
                name: "map_values(expr)",
                description: "Apply an expression to every value of an object (or element of an array) in place, preserving the structure.",
                examples: [
                    JQExample(input: "{\"a\": 1, \"b\": 2}", expression: "map_values(. + 10)", output: "{\"a\": 11, \"b\": 12}")
                ]
            )

            JQEntry(
                name: "del(path)",
                description: "Deletes a field from an object or an element from an array.",
                examples: [
                    JQExample(input: "{\"a\": 1, \"b\": 2, \"c\": 3}", expression: "del(.b)", output: "{\"a\": 1, \"c\": 3}"),
                    JQExample(input: "[1, 2, 3]", expression: "del(.[1])", output: "[1, 3]")
                ]
            )
        }

        // MARK: - Type Functions
        Group {
            JQCategory("Type & Conversion Functions")

            JQEntry(
                name: "type",
                description: "Returns the type of the input as a string: \"object\", \"array\", \"string\", \"number\", \"boolean\", or \"null\".",
                examples: [
                    JQExample(input: "42", expression: "type", output: "\"number\""),
                    JQExample(input: "[1, 2]", expression: "type", output: "\"array\""),
                    JQExample(input: "null", expression: "type", output: "\"null\"")
                ]
            )

            JQEntry(
                name: "length",
                description: "Returns the length of the input. For strings: character count. For arrays: element count. For objects: key count. For null: 0.",
                examples: [
                    JQExample(input: "\"hello\"", expression: "length", output: "5"),
                    JQExample(input: "[1, 2, 3]", expression: "length", output: "3"),
                    JQExample(input: "{\"a\": 1, \"b\": 2}", expression: "length", output: "2")
                ]
            )

            JQEntry(
                name: "tostring",
                description: "Converts the input to a string representation.",
                examples: [
                    JQExample(input: "42", expression: "tostring", output: "\"42\""),
                    JQExample(input: "true", expression: "tostring", output: "\"true\""),
                    JQExample(input: "[1, 2]", expression: "tostring", output: "\"[1,2]\"")
                ]
            )

            JQEntry(
                name: "tonumber",
                description: "Converts a string to a number.",
                examples: [
                    JQExample(input: "\"42\"", expression: "tonumber", output: "42"),
                    JQExample(input: "\"3.14\"", expression: "tonumber", output: "3.14")
                ]
            )

            JQEntry(
                name: "tojson, fromjson",
                description: "tojson serializes a value to a JSON string. fromjson parses a JSON string back to a value.",
                examples: [
                    JQExample(input: "{\"a\": 1}", expression: "tojson", output: "\"{\\\"a\\\":1}\""),
                    JQExample(input: "\"{\\\"a\\\": 1}\"", expression: "fromjson", output: "{\"a\": 1}")
                ]
            )
        }

        // MARK: - Math Functions
        Group {
            JQCategory("Math Functions")

            JQEntry(
                name: "abs",
                description: "Absolute value of a number.",
                examples: [
                    JQExample(input: "-5", expression: "abs", output: "5")
                ]
            )

            JQEntry(
                name: "floor, ceil, round",
                description: "floor rounds down, ceil rounds up, round rounds to nearest integer.",
                examples: [
                    JQExample(input: "3.7", expression: "floor", output: "3"),
                    JQExample(input: "3.2", expression: "ceil", output: "4"),
                    JQExample(input: "3.5", expression: "round", output: "4")
                ]
            )

            JQEntry(
                name: "sqrt",
                description: "Square root of a number.",
                examples: [
                    JQExample(input: "16", expression: "sqrt", output: "4")
                ]
            )

            JQEntry(
                name: "isinfinite, isnan, isnormal",
                description: "Tests for special floating-point values.",
                examples: [
                    JQExample(input: "null", expression: "infinite | isinfinite", output: "true"),
                    JQExample(input: "null", expression: "nan | isnan", output: "true"),
                    JQExample(input: "42", expression: "isnormal", output: "true")
                ]
            )

            JQEntry(
                name: "infinite, nan",
                description: "Produces the special IEEE 754 infinity and NaN values.",
                examples: [
                    JQExample(input: "null", expression: "infinite", output: "1.7976931348623157e+308"),
                    JQExample(input: "null", expression: "nan", output: "nan")
                ]
            )

            JQEntry(
                name: "now",
                description: "Returns the current Unix timestamp as a number.",
                examples: [
                    JQExample(input: "null", expression: "now | . > 0", output: "true")
                ]
            )
        }

        // MARK: - Path Functions
        Group {
            JQCategory("Path Functions")

            JQEntry(
                name: "path(expr)",
                description: "Returns the path to each output of the expression as an array of keys/indices.",
                examples: [
                    JQExample(input: "{\"a\": {\"b\": 1}}", expression: "path(.a.b)", output: "[\"a\", \"b\"]")
                ]
            )

            JQEntry(
                name: "getpath(path)",
                description: "Gets the value at the given path (an array of keys/indices).",
                examples: [
                    JQExample(input: "{\"a\": {\"b\": 42}}", expression: "getpath([\"a\", \"b\"])", output: "42")
                ]
            )

            JQEntry(
                name: "setpath(path; value)",
                description: "Sets the value at the given path, creating intermediate structures as needed.",
                examples: [
                    JQExample(input: "{\"a\": {\"b\": 1}}", expression: "setpath([\"a\", \"b\"]; 99)", output: "{\"a\": {\"b\": 99}}")
                ]
            )

            JQEntry(
                name: "delpaths(paths)",
                description: "Deletes the values at each of the given paths.",
                examples: [
                    JQExample(input: "{\"a\": 1, \"b\": 2, \"c\": 3}", expression: "delpaths([[\"a\"], [\"c\"]])", output: "{\"b\": 2}")
                ]
            )

            JQEntry(
                name: "leaf_paths",
                description: "Returns all paths to leaf (non-container) values.",
                examples: [
                    JQExample(input: "{\"a\": {\"b\": 1}, \"c\": 2}", expression: "leaf_paths", output: "[[\"a\", \"b\"], [\"c\"]]")
                ]
            )

            JQEntry(
                name: "recurse",
                description: "Equivalent to the recursive descent operator (..). Produces every value at all depths.",
                examples: [
                    JQExample(input: "{\"a\": {\"b\": 1}}", expression: "[recurse | scalars]", output: "[1]")
                ]
            )
        }

        // MARK: - Utility Functions
        Group {
            JQCategory("Utility Functions")

            JQEntry(
                name: "debug",
                description: "Passes through the input unchanged. In standard jq this prints to stderr; in Bonsai it's a no-op passthrough useful for composing pipelines.",
                examples: [
                    JQExample(input: "42", expression: "debug", output: "42")
                ]
            )

            JQEntry(
                name: "error, error(msg)",
                description: "Raises an error. With an argument, uses it as the error message.",
                examples: [
                    JQExample(input: "null", expression: "if . == null then error(\"input was null\") else . end", output: "(error: input was null)")
                ]
            )

            JQEntry(
                name: "builtins",
                description: "Returns an array of all supported built-in function names.",
                examples: [
                    JQExample(input: "null", expression: "builtins | length", output: "74")
                ]
            )
        }

        // MARK: - Common Patterns
        Group {
            JQCategory("Common Patterns & Recipes")

            HelpParagraph("These patterns combine multiple jq features to accomplish common tasks:")

            JQPattern(
                title: "Filter objects by a field value",
                expression: ".items[] | select(.price > 100)",
                explanation: "Iterates over the items array and keeps only those where price exceeds 100."
            )

            JQPattern(
                title: "Extract a list of values",
                expression: "[.users[] | .email]",
                explanation: "Collects all email addresses from a users array into a new array."
            )

            JQPattern(
                title: "Count items matching a condition",
                expression: "[.items[] | select(.active)] | length",
                explanation: "Filters for active items, collects them in an array, then counts."
            )

            JQPattern(
                title: "Reshape objects",
                expression: ".users[] | {name, contact: .email}",
                explanation: "Creates new objects with only name and a renamed email field."
            )

            JQPattern(
                title: "Sum a field across array elements",
                expression: "[.orders[] | .total] | add",
                explanation: "Extracts all totals into an array and sums them."
            )

            JQPattern(
                title: "Find unique values of a field",
                expression: "[.items[] | .category] | unique",
                explanation: "Extracts all categories and removes duplicates."
            )

            JQPattern(
                title: "Group and count",
                expression: "group_by(.status) | map({status: .[0].status, count: length})",
                explanation: "Groups items by status, then creates summary objects with counts."
            )

            JQPattern(
                title: "Flatten nested arrays",
                expression: "[.sections[] | .items[]] | sort_by(.name)",
                explanation: "Collects items from all sections into a flat sorted list."
            )

            JQPattern(
                title: "Transform keys",
                expression: "with_entries(.key |= ascii_downcase)",
                explanation: "Converts all object keys to lowercase."
            )

            JQPattern(
                title: "Conditional transformation",
                expression: ".items | map(if .price > 100 then .category = \"premium\" else . end)",
                explanation: "Marks items over 100 as premium while leaving others unchanged."
            )

            JQPattern(
                title: "Check if a nested path exists",
                expression: ".config | has(\"database\") and (.database | has(\"host\"))",
                explanation: "Tests for the existence of a nested configuration path."
            )

            JQPattern(
                title: "Merge arrays of objects",
                expression: "[.users, .admins] | add | unique_by(.id)",
                explanation: "Combines two arrays and removes duplicates by ID."
            )
        }
    }
}

// MARK: - JQ Reference Components

private struct JQCategory: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.title2)
            .fontWeight(.bold)
            .padding(.top, 28)
            .padding(.bottom, 12)
    }
}

private struct JQExample {
    let input: String
    let expression: String
    let output: String
}

private struct JQEntry: View {
    let name: String
    let description: String
    let examples: [JQExample]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(name)
                .font(.headline)
                .padding(.top, 12)

            Text(description)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(Array(examples.enumerated()), id: \.offset) { _, example in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top, spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Input")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            Text(example.input)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        .frame(minWidth: 100, alignment: .leading)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Expression")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            Text(example.expression)
                                .font(.system(.caption, design: .monospaced))
                                .fontWeight(.medium)
                        }
                        .frame(minWidth: 150, alignment: .leading)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Output")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            Text(example.output)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.green)
                        }
                        .frame(minWidth: 100, alignment: .leading)
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(.bottom, 4)
    }
}

private struct JQPattern: View {
    let title: String
    let expression: String
    let explanation: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.top, 8)

            Text(expression)
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))

            Text(explanation)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 4)
    }
}
