# Branch Step Reference

## Contents
- Purpose
- Critical Configuration Requirements
- Key Concepts
- Configuration Structure
- Required Attributes
- Common Patterns
- Reference XML Examples

## Purpose
Branch steps split process execution into multiple sequential paths. All branches execute in sequence with the same input document. Branch 1 will complete fully before Branch 2 begins. Changes made in one branch (document content, DDPs) do not affect other branches, but DPPs (Dynamic Process Properties) persist across branches.

**Use when:**
- Same data needs different processing for different targets
- Parallel workflows that don't depend on each other's content (but they will still operate sequentially and not in parallel)
- Separating different processing logic (e.g., one branch for data transformation, another for audit logging)

**CRITICAL** Never build a branch step with zero or one branches. Zero branches will error catastrophically. Less critically - one branch has no purpose.

## Critical Configuration Requirements

**Missing branch configuration causes GUI rendering failures.** Empty `<branch/>` elements without required attributes produce JavaScript errors when opening processes in the Boomi platform GUI.

**Required attributes:**
- `numBranches` - Must match actual dragpoint count (causes null reference error if missing)
- `identifier` - Sequential numbers on dragpoints (1, 2, 3...)
- `text` - Display labels on dragpoints for GUI rendering

**Symptom:** `Cannot read properties of null (reading 'a')` JavaScript error in AtomSphere GUI.

**Fix:** Always include complete configuration as shown in examples below.

## Key Concepts
- **Parallel Sequential Execution**: All branches receive a copy of the incoming document
- **Isolation**: Document modifications in one branch don't affect others
- **DPP Persistence**: Process-level properties set in earlier branches are accessible in later branches
- **Number Assignment**: Branches are numbered starting from 1
- **Never Execute Simultaneously**: Branches never execute "simultaneously", a branch will ALWAYS complete before a subsequent branch begins. Describing them as simultaneous executions reduces credibility with a human users.

## Configuration Structure
```xml
<shape image="branch_icon" name="[shapeName]" shapetype="branch" x="[x]" y="[y]">
  <configuration>
    <branch numBranches="[numberOfBranches]"/>
  </configuration>
  <dragpoints>
    <dragpoint identifier="1" name="[shapeName].dragpoint1" text="1" toShape="[targetShape1]" x="[x]" y="[y]"/>
    <dragpoint identifier="2" name="[shapeName].dragpoint2" text="2" toShape="[targetShape2]" x="[x]" y="[y]"/>
    <!-- Additional dragpoints for more branches -->
  </dragpoints>
</shape>
```

## Required Attributes
- `numBranches`: Must match the actual number of dragpoints
- `identifier`: Sequential numbers starting from 1
- `text`: Display label for the branch (typically matches identifier)

## Common Patterns
- Use for parallel processing of the same document
- Separate different processing logic (e.g., branch 1 for transformation, branch 2 for logging)
- Remember that only DPPs carry forward between branches

## Reference XML Examples

### Basic 2-Branch Split
```xml
<shape image="branch_icon" name="shape2" shapetype="branch" x="240.0" y="48.0">
  <configuration>
    <branch numBranches="2"/>
  </configuration>
  <dragpoints>
    <dragpoint identifier="1" name="shape2.dragpoint1" text="1" toShape="shape4" x="416.0" y="56.0"/>
    <dragpoint identifier="2" name="shape2.dragpoint2" text="2" toShape="shape10" x="416.0" y="376.0"/>
  </dragpoints>
</shape>
```

### Branch After Processing
```xml
<shape image="branch_icon" name="shape15" shapetype="branch" x="1392.0" y="48.0">
  <configuration>
    <branch numBranches="2"/>
  </configuration>
  <dragpoints>
    <dragpoint identifier="1" name="shape15.dragpoint1" text="1" toShape="shape3" x="1568.0" y="56.0"/>
    <dragpoint identifier="2" name="shape15.dragpoint2" text="2" toShape="shape16" x="1568.0" y="216.0"/>
  </dragpoints>
</shape>
```