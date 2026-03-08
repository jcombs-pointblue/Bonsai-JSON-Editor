# Sample jq Queries for sample.json

## Basic Access

| Query | Description |
|-------|-------------|
| `.company` | Top-level string |
| `.users \| length` | Count users |
| `.users[0]` | First user |
| `.departments` | All departments |
| `.config.version` | Nested config value |

## Filtering

| Query | Description |
|-------|-------------|
| `.users[] \| select(.active)` | Active users only |
| `.users[] \| select(.role == "developer") \| .name` | Developer names |
| `.users[] \| select(.skills \| contains(["Python"])) \| .name` | Users who know Python |
| `.users[] \| select(.projects \| length > 2) \| .name` | Users with 3+ projects |
| `.projects[] \| select(.status == "active") \| .name` | Active project names |

## Transforming

| Query | Description |
|-------|-------------|
| `.users[] \| {name, department, role}` | Reshape user objects |
| `.users[] \| {name, project_count: (.projects \| length)}` | Computed fields |
| `[.users[] \| select(.active) \| .email]` | Collect active emails into array |
| `.users[] \| {name, city: .address.city}` | Flatten nested fields |
| `.projects[] \| {name, is_active: (.status == "active")}` | Boolean computed fields |

## Aggregation

| Query | Description |
|-------|-------------|
| `[.departments[] \| .budget] \| add` | Total budget |
| `[.departments[] \| .budget] \| add / length` | Average budget |
| `.departments \| min_by(.budget) \| .name` | Smallest budget department |
| `.departments \| max_by(.headcount) \| .name` | Largest department |
| `[.users[] \| .skills[]] \| unique \| sort` | All unique skills sorted |
| `[.users[] \| .skills[]] \| unique \| length` | Count unique skills |

## Grouping

| Query | Description |
|-------|-------------|
| `.users \| group_by(.department) \| map({dept: .[0].department, count: length})` | Headcount by department |
| `.users \| group_by(.role) \| map({role: .[0].role, names: map(.name)})` | Names grouped by role |
| `[.users[] \| .projects[]] \| group_by(.status) \| map({status: .[0].status, count: length})` | Project count by status |

## Nested Access

| Query | Description |
|-------|-------------|
| `.users[] \| select(.address.state == "CA") \| .name` | Users in California |
| `.projects[] \| select(.tags \| contains(["internal"])) \| .name` | Internal projects |
| `.config.features \| to_entries \| map(select(.value)) \| map(.key)` | Enabled feature flags |
| `.config.limits \| to_entries \| map({(.key): .value}) \| add` | Limits as flat object |

## String Operations

| Query | Description |
|-------|-------------|
| `.users[] \| .email \| split("@") \| .[1]` | Extract email domains |
| `.users[] \| select(.name \| startswith("C")) \| .name` | Names starting with C |
| `[.projects[] \| .tags[]] \| unique \| sort` | All unique tags sorted |
| `.users[] \| {name, initials: (.name \| split(" ") \| map(.[:1]) \| join(""))}` | Generate initials |

## Object Manipulation

| Query | Description |
|-------|-------------|
| `.users[0] \| del(.address, .projects)` | Remove fields from object |
| `.users[0] \| keys` | List all keys of first user |
| `.users[0] \| with_entries(select(.key \| test("name\|email\|role")))` | Keep only matching keys |
| `.config \| .. \| numbers` | Find all numbers in config |

## Combining Multiple Operations

| Query | Description |
|-------|-------------|
| `.users \| sort_by(.name) \| map({name, role})` | Sorted user roster |
| `{active_users: [.users[] \| select(.active) \| .name], inactive: [.users[] \| select(.active \| not) \| .name]}` | Partition users by status |
| `.users \| map(select(.active)) \| sort_by(.projects \| length) \| reverse \| .[0] \| {name, projects: (.projects \| length)}` | Most active user by project count |
