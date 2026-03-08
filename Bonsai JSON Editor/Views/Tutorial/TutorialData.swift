import Foundation

/// A single step in the tutorial, representing one jq query to learn
struct TutorialStep: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let query: String
    let hint: String?
}

/// A category of tutorial steps
struct TutorialCategory: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let introduction: String
    let steps: [TutorialStep]
}

/// All tutorial content, including the embedded sample JSON
enum TutorialContent {

    /// The embedded sample JSON string
    static let sampleJSON: String = """
    {
      "company": "Acme Corp",
      "founded": 2018,
      "active": true,
      "departments": [
        {
          "name": "Engineering",
          "budget": 450000,
          "headcount": 12
        },
        {
          "name": "Design",
          "budget": 180000,
          "headcount": 5
        },
        {
          "name": "Marketing",
          "budget": 220000,
          "headcount": 7
        }
      ],
      "users": [
        {
          "id": 1,
          "name": "Alice Chen",
          "email": "alice@acme.com",
          "role": "admin",
          "department": "Engineering",
          "active": true,
          "skills": ["Swift", "Python", "Rust"],
          "projects": [
            {"name": "Bonsai", "status": "active", "priority": "high"},
            {"name": "Atlas", "status": "completed", "priority": "medium"}
          ],
          "address": {
            "city": "San Francisco",
            "state": "CA",
            "zip": "94105"
          }
        },
        {
          "id": 2,
          "name": "Bob Martinez",
          "email": "bob@acme.com",
          "role": "developer",
          "department": "Engineering",
          "active": true,
          "skills": ["JavaScript", "TypeScript", "React"],
          "projects": [
            {"name": "Portal", "status": "active", "priority": "high"},
            {"name": "Bonsai", "status": "active", "priority": "high"},
            {"name": "Lighthouse", "status": "paused", "priority": "low"}
          ],
          "address": {
            "city": "Austin",
            "state": "TX",
            "zip": "73301"
          }
        },
        {
          "id": 3,
          "name": "Carol Wright",
          "email": "carol@acme.com",
          "role": "designer",
          "department": "Design",
          "active": true,
          "skills": ["Figma", "CSS", "Illustration"],
          "projects": [
            {"name": "Bonsai", "status": "active", "priority": "high"}
          ],
          "address": {
            "city": "Portland",
            "state": "OR",
            "zip": "97201"
          }
        },
        {
          "id": 4,
          "name": "David Park",
          "email": "david@acme.com",
          "role": "developer",
          "department": "Engineering",
          "active": false,
          "skills": ["Go", "Kubernetes", "Terraform"],
          "projects": [
            {"name": "Atlas", "status": "completed", "priority": "medium"},
            {"name": "Lighthouse", "status": "paused", "priority": "low"}
          ],
          "address": {
            "city": "Seattle",
            "state": "WA",
            "zip": "98101"
          }
        },
        {
          "id": 5,
          "name": "Eva Johansson",
          "email": "eva@acme.com",
          "role": "manager",
          "department": "Marketing",
          "active": true,
          "skills": ["Analytics", "SEO", "Content Strategy"],
          "projects": [
            {"name": "Portal", "status": "active", "priority": "high"},
            {"name": "Campaign Q2", "status": "active", "priority": "medium"}
          ],
          "address": {
            "city": "Chicago",
            "state": "IL",
            "zip": "60601"
          }
        },
        {
          "id": 6,
          "name": "Frank Nwosu",
          "email": "frank@acme.com",
          "role": "developer",
          "department": "Engineering",
          "active": true,
          "skills": ["Python", "Machine Learning", "SQL"],
          "projects": [
            {"name": "Atlas", "status": "completed", "priority": "medium"},
            {"name": "Bonsai", "status": "active", "priority": "high"},
            {"name": "ML Pipeline", "status": "active", "priority": "high"}
          ],
          "address": {
            "city": "San Francisco",
            "state": "CA",
            "zip": "94107"
          }
        }
      ],
      "projects": [
        {
          "name": "Bonsai",
          "status": "active",
          "started": "2025-01-15",
          "tags": ["tools", "developer-experience", "open-source"]
        },
        {
          "name": "Atlas",
          "status": "completed",
          "started": "2024-03-01",
          "tags": ["infrastructure", "internal"]
        },
        {
          "name": "Portal",
          "status": "active",
          "started": "2025-06-10",
          "tags": ["customer-facing", "web"]
        },
        {
          "name": "Lighthouse",
          "status": "paused",
          "started": "2024-11-20",
          "tags": ["monitoring", "internal"]
        },
        {
          "name": "Campaign Q2",
          "status": "active",
          "started": "2026-01-05",
          "tags": ["marketing", "growth"]
        },
        {
          "name": "ML Pipeline",
          "status": "active",
          "started": "2025-09-12",
          "tags": ["data", "infrastructure", "machine-learning"]
        }
      ],
      "config": {
        "version": "2.1.0",
        "features": {
          "dark_mode": true,
          "notifications": true,
          "beta_access": false
        },
        "limits": {
          "max_users": 50,
          "max_projects": 20,
          "storage_gb": 100
        }
      }
    }
    """

    /// Parsed sample JSON node, computed once
    static let sampleNode: JSONNode = {
        // swiftlint:disable:next force_try
        try! JSONParser.parse(sampleJSON)
    }()

    /// All tutorial categories with their steps
    static let categories: [TutorialCategory] = [

        // MARK: - Basic Access
        TutorialCategory(
            name: "Basic Access",
            icon: "rectangle.and.text.magnifyingglass",
            introduction: "Learn to navigate JSON data by accessing fields, array elements, and nested paths.",
            steps: [
                TutorialStep(
                    title: "The Identity Filter",
                    description: "The simplest jq expression is a dot (.), called the identity filter. It returns the entire input unchanged. This is your starting point for any jq exploration.",
                    query: ".",
                    hint: "Try this first whenever you open a new JSON file to see its full structure."
                ),
                TutorialStep(
                    title: "Accessing a Top-Level Field",
                    description: "Use dot notation to access a field by name. .company extracts the value of the \"company\" key from the root object.",
                    query: ".company",
                    hint: nil
                ),
                TutorialStep(
                    title: "Counting Array Elements",
                    description: "The pipe operator (|) chains filters together. Here we access the users array and pipe it to length to count how many users exist.",
                    query: ".users | length",
                    hint: "The | operator works like Unix pipes \u{2014} the output of the left side becomes the input to the right side."
                ),
                TutorialStep(
                    title: "Accessing an Array Element",
                    description: "Use bracket notation with a zero-based index to access a specific array element. .users[0] gets the first user.",
                    query: ".users[0]",
                    hint: nil
                ),
                TutorialStep(
                    title: "Listing All Departments",
                    description: "Access the departments array to see all department objects at once.",
                    query: ".departments",
                    hint: nil
                ),
                TutorialStep(
                    title: "Nested Field Access",
                    description: "Chain dot accesses to reach values deep in the structure. .config.version navigates into the config object and then to its version field.",
                    query: ".config.version",
                    hint: "You can chain as many levels as needed: .config.features.dark_mode"
                ),
            ]
        ),

        // MARK: - Filtering
        TutorialCategory(
            name: "Filtering",
            icon: "line.3.horizontal.decrease.circle",
            introduction: "Use select() to filter data based on conditions. This is one of jq's most powerful features.",
            steps: [
                TutorialStep(
                    title: "Select Active Users",
                    description: "The .[] iterator produces each element of an array one at a time. Combined with select(), you can filter for elements matching a condition. Here we keep only users where .active is true.",
                    query: ".users[] | select(.active)",
                    hint: ".[] explodes an array into individual elements. select() keeps only those where the condition is truthy."
                ),
                TutorialStep(
                    title: "Filter by Field Value",
                    description: "Combine select() with an equality test to find users with a specific role, then extract just their names.",
                    query: ".users[] | select(.role == \"developer\") | .name",
                    hint: "Each | passes results one at a time, so .name runs on each filtered user individually."
                ),
                TutorialStep(
                    title: "Filter by Array Contents",
                    description: "Use contains() inside select() to find users whose skills array includes a particular skill.",
                    query: ".users[] | select(.skills | contains([\"Python\"])) | .name",
                    hint: "contains() does deep comparison. For arrays, it checks if all elements in the argument exist in the input."
                ),
                TutorialStep(
                    title: "Filter by Computed Value",
                    description: "You can use any expression inside select(). Here we find users with more than 2 projects by checking the length of their projects array.",
                    query: ".users[] | select(.projects | length > 2) | .name",
                    hint: nil
                ),
                TutorialStep(
                    title: "Filter Projects by Status",
                    description: "The same pattern works on any array. Filter the projects array for those with an \"active\" status.",
                    query: ".projects[] | select(.status == \"active\") | .name",
                    hint: nil
                ),
            ]
        ),

        // MARK: - Transforming
        TutorialCategory(
            name: "Transforming",
            icon: "arrow.triangle.2.circlepath",
            introduction: "Reshape JSON data by constructing new objects and arrays from existing data.",
            steps: [
                TutorialStep(
                    title: "Reshape Objects",
                    description: "Construct new objects using {key: expr} syntax. Extract only the fields you need from each user.",
                    query: ".users[] | {name, department, role}",
                    hint: "{name} is shorthand for {name: .name}. This is called shorthand field syntax."
                ),
                TutorialStep(
                    title: "Computed Fields",
                    description: "Object construction can include computed values. Here we count each user's projects inline.",
                    query: ".users[] | {name, project_count: (.projects | length)}",
                    hint: "Parentheses are needed around complex expressions used as values in object construction."
                ),
                TutorialStep(
                    title: "Collect Results into an Array",
                    description: "Wrap an expression in [...] to collect all outputs into a single array. This collects active users' emails.",
                    query: "[.users[] | select(.active) | .email]",
                    hint: "Without the outer brackets, each email would be a separate output. The brackets collect them into one array."
                ),
                TutorialStep(
                    title: "Flatten Nested Fields",
                    description: "Reach into nested objects to bring values up to a flatter structure.",
                    query: ".users[] | {name, city: .address.city}",
                    hint: nil
                ),
                TutorialStep(
                    title: "Boolean Computed Fields",
                    description: "Computed fields can be boolean expressions. Here we add an is_active field based on comparing the status.",
                    query: ".projects[] | {name, is_active: (.status == \"active\")}",
                    hint: nil
                ),
            ]
        ),

        // MARK: - Aggregation
        TutorialCategory(
            name: "Aggregation",
            icon: "chart.bar",
            introduction: "Summarize data by computing totals, averages, min/max, and collecting unique values.",
            steps: [
                TutorialStep(
                    title: "Sum Values",
                    description: "Collect numbers into an array, then use add to sum them. This calculates the total budget across all departments.",
                    query: "[.departments[] | .budget] | add",
                    hint: "add works on arrays of numbers (sum), strings (concatenation), arrays (flatten), and objects (merge)."
                ),
                TutorialStep(
                    title: "Compute an Average",
                    description: "Divide the sum by the count to get an average. Here we compute the average department budget.",
                    query: "[.departments[] | .budget] | add / length",
                    hint: "add / length works because add gives the sum and length gives the count on the same input array."
                ),
                TutorialStep(
                    title: "Find the Minimum",
                    description: "Use min_by to find the element with the smallest value for a given field. Which department has the smallest budget?",
                    query: ".departments | min_by(.budget) | .name",
                    hint: nil
                ),
                TutorialStep(
                    title: "Find the Maximum",
                    description: "Find the department with the most employees using max_by on headcount.",
                    query: ".departments | max_by(.headcount) | .name",
                    hint: nil
                ),
                TutorialStep(
                    title: "Collect Unique Values",
                    description: "Iterate over nested arrays to collect all unique skills across all users, then sort them.",
                    query: "[.users[] | .skills[]] | unique | sort",
                    hint: "The double iteration .users[] | .skills[] flattens the nested skill arrays into a single stream."
                ),
                TutorialStep(
                    title: "Count Unique Values",
                    description: "Chain unique with length to count how many distinct skills exist across the company.",
                    query: "[.users[] | .skills[]] | unique | length",
                    hint: nil
                ),
            ]
        ),

        // MARK: - Grouping
        TutorialCategory(
            name: "Grouping",
            icon: "rectangle.3.group",
            introduction: "Use group_by to organize data into groups, then summarize each group.",
            steps: [
                TutorialStep(
                    title: "Group by Department",
                    description: "group_by(.department) organizes users into sub-arrays by department. We then map each group to an object showing the department name and count.",
                    query: ".users | group_by(.department) | map({dept: .[0].department, count: length})",
                    hint: "After group_by, each group is an array. .[0].department gets the department from any member; length counts members."
                ),
                TutorialStep(
                    title: "Group Names by Role",
                    description: "Group users by role, then extract the list of names in each group.",
                    query: ".users | group_by(.role) | map({role: .[0].role, names: map(.name)})",
                    hint: "The inner map(.name) runs on each group array to extract just the names."
                ),
                TutorialStep(
                    title: "Count Projects by Status",
                    description: "First flatten all user projects into a single list, then group by status and count each group.",
                    query: "[.users[] | .projects[]] | group_by(.status) | map({status: .[0].status, count: length})",
                    hint: nil
                ),
            ]
        ),

        // MARK: - Nested Access
        TutorialCategory(
            name: "Nested Access",
            icon: "arrow.down.right",
            introduction: "Navigate deep into nested structures using chained field access and conditions.",
            steps: [
                TutorialStep(
                    title: "Filter by Nested Field",
                    description: "Access nested object fields inside select() to filter by deeply nested values. Find users in California.",
                    query: ".users[] | select(.address.state == \"CA\") | .name",
                    hint: nil
                ),
                TutorialStep(
                    title: "Filter by Array Contents",
                    description: "Use contains to check if a tags array includes a specific tag. Find internal projects.",
                    query: ".projects[] | select(.tags | contains([\"internal\"])) | .name",
                    hint: nil
                ),
                TutorialStep(
                    title: "Enabled Feature Flags",
                    description: "Convert an object to key-value entries, filter for truthy values, then extract the keys. This finds which features are turned on.",
                    query: ".config.features | to_entries | map(select(.value)) | map(.key)",
                    hint: "to_entries converts {dark_mode: true, ...} into [{key: \"dark_mode\", value: true}, ...]."
                ),
                TutorialStep(
                    title: "Find All Numbers in Config",
                    description: "The recursive descent operator (..) visits every value at all depths. Combined with numbers, it extracts only numeric values.",
                    query: ".config | .. | numbers",
                    hint: ".. recursively descends into the structure. Type selectors like numbers keep only matching types."
                ),
            ]
        ),

        // MARK: - String Operations
        TutorialCategory(
            name: "String Operations",
            icon: "textformat",
            introduction: "jq has powerful string functions for splitting, matching, and transforming text.",
            steps: [
                TutorialStep(
                    title: "Split and Extract",
                    description: "Use split() to break a string into parts. Here we extract the email domain by splitting on '@' and taking the second element.",
                    query: ".users[] | .email | split(\"@\") | .[1]",
                    hint: "split() returns an array of substrings. .[1] gets the second element (the domain)."
                ),
                TutorialStep(
                    title: "Filter by String Prefix",
                    description: "Use startswith() inside select() to find names beginning with a specific letter.",
                    query: ".users[] | select(.name | startswith(\"C\")) | .name",
                    hint: nil
                ),
                TutorialStep(
                    title: "Collect Unique Tags",
                    description: "Flatten all project tags into a single stream, collect them, remove duplicates, and sort.",
                    query: "[.projects[] | .tags[]] | unique | sort",
                    hint: nil
                ),
                TutorialStep(
                    title: "Generate Initials",
                    description: "A more complex string operation: split the name on spaces, take the first character of each part, and join them together.",
                    query: ".users[] | {name, initials: (.name | split(\" \") | map(.[:1]) | join(\"\"))}",
                    hint: ".[:1] is string slicing \u{2014} it takes the first character. join() concatenates with a separator."
                ),
            ]
        ),

        // MARK: - Object Manipulation
        TutorialCategory(
            name: "Object Manipulation",
            icon: "slider.horizontal.3",
            introduction: "Modify object structure by removing fields, listing keys, and selectively keeping entries.",
            steps: [
                TutorialStep(
                    title: "Remove Fields",
                    description: "Use del() to remove specific fields from an object. Here we strip the address and projects from the first user.",
                    query: ".users[0] | del(.address, .projects)",
                    hint: "del() accepts a comma-separated list of paths to remove."
                ),
                TutorialStep(
                    title: "List All Keys",
                    description: "The keys function returns a sorted array of all key names in an object.",
                    query: ".users[0] | keys",
                    hint: "Use keys_unsorted if you want to preserve the original key order."
                ),
                TutorialStep(
                    title: "Keep Only Matching Keys",
                    description: "Combine with_entries with select and test (regex) to keep only keys matching a pattern.",
                    query: ".users[0] | with_entries(select(.key | test(\"name|email|role\")))",
                    hint: "with_entries is shorthand for to_entries | map(...) | from_entries."
                ),
            ]
        ),

        // MARK: - Combining Operations
        TutorialCategory(
            name: "Combining Operations",
            icon: "gearshape.2",
            introduction: "Combine multiple jq techniques into powerful data transformations.",
            steps: [
                TutorialStep(
                    title: "Sorted User Roster",
                    description: "Sort the users array by name, then reshape each user to show only name and role.",
                    query: ".users | sort_by(.name) | map({name, role})",
                    hint: "sort_by returns a sorted array. map then transforms each element."
                ),
                TutorialStep(
                    title: "Partition Users by Status",
                    description: "Build an object with two arrays: one for active users and one for inactive, by running two separate filters on the same input.",
                    query: "{active_users: [.users[] | select(.active) | .name], inactive: [.users[] | select(.active | not) | .name]}",
                    hint: "Each field in the output object runs its own independent pipeline against the original input."
                ),
                TutorialStep(
                    title: "Most Active User",
                    description: "Chain multiple operations: filter for active users, sort by project count, reverse for descending order, take the first, and reshape the output.",
                    query: ".users | map(select(.active)) | sort_by(.projects | length) | reverse | .[0] | {name, projects: (.projects | length)}",
                    hint: "This is a multi-step pipeline: filter \u{2192} sort \u{2192} reverse \u{2192} pick first \u{2192} reshape."
                ),
            ]
        ),
    ]
}
