# Business Rules Step

## Contents
- Purpose
- Key Concepts
- Configuration Structure
- Rule Inputs
- Conditions
- Operators
- Error Messages
- Repeating Elements
- Reading the Failure Message
- Building Instructions
- Diagnosing `null`
- Common Gotchas
- XML Reference
- Best Practices

## Purpose
The Business Rules step checks a document against multiple named rules and routes it down an Accepted or Rejected path. Each rule carries its own condition and its own error message; failures from all rules are aggregated into a single XML document attached to the rejected document as a tracked property.

**Use when:**
- Validating a document against one or more named conditions where the failure reason must be reported
- Replacing a chain of Decision steps that exist only to validate
- Field-content validation needing nested AND/OR logic
- Validating each occurrence of a repeating element independently

Choose a Decision step when you only need to route on a condition and nothing downstream has to explain why, and a Route step for switch/case dispatch on a single value. What Business Rules adds is named rules plus an aggregated, human-readable failure message.

**Performance favors Business Rules, and the margin grows with the number of conditions.** Thirty rules in one Business Rules shape run several times faster than thirty equivalent Decision steps, because the dominant cost in a Decision chain is per-shape overhead rather than parsing — each document is routed through every shape, while Business Rules evaluates all its rules inside one shape against one parse. The marginal cost of an additional rule is a small fraction of the cost of an additional Decision step, and even a single rule is not slower.

## Key Concepts

### Two Fixed Paths
Exactly two outbound paths, with `identifier` and `text` both set to the capitalized words `Accepted` and `Rejected` — not `true`/`false` like Decision, and not numeric keys like Route.

Accepted documents traverse the Accepted path before rejected documents traverse the Rejected path.

### The Condition Expresses the PASS State
This is the single easiest thing to invert. `<condition>` asserts what must be **TRUE** for the document to be accepted; `<errorMessage>` is what to say when that assertion breaks.

A spec sentence like *"reject when status is not ACTIVE"* becomes `condition: status = "ACTIVE"` with message `"Status must be ACTIVE."` — **not** `status != "ACTIVE"`.

### Rejection Is Routing, Not Failure
A rejected document produces a normal, successful execution. There is no implicit exception and no error status. If a rejection must fail the process or the document, put an Exception step on the Rejected path.

### The Two Paths Are Not Exhaustive
A document that does not parse against the declared profile goes down **neither** path — it errors instead, and both paths log `No documents found`. "Not Accepted" does not imply "Rejected", and a Rejected-path handler will never see parse failures. Wrap the step in a Try/Catch if malformed input is possible.

### No Reusable Component
There is no Business Rules component type. The configuration lives entirely inline in the process XML, so rules cannot be shared between processes — each shape carries its own copy.

### `xmlns:xsi` Is Mandatory
Rule internals are discriminated by `xsi:type`, so the root `<bns:Component>` element must declare:

```
xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
```

Omitting it makes the document malformed and the push fails with the opaque message `Unable to read message body.  Please make sure the structure is correct.`, which names nothing. See Gotcha 8.

### Rule Order
Rules execute in **XML document order**. The `key` attribute is an identifier only and is not a sort field. Failure messages aggregate in execution order, so document order is directly observable in the output.

## Configuration Structure

```xml
<shape image="businessrules_icon" name="[shapeName]" shapetype="businessrules" userlabel="[display label]" x="[x]" y="[y]">
  <configuration>
    <businessrules profileId="[profile GUID]" profileName="[display name]" profileType="[profile.json|profile.xml|profile.flatfile|profile.db|profile.edi]">
      <rule key="[int]" name="[rule name]">
        <input .../>          <!-- 0..N, referenced by id; order among inputs is free -->
        <condition .../>      <!-- exactly 1, containing at least one comparison -->
        <errorMessage .../>   <!-- exactly 1 -->
      </rule>
      <!-- additional rule elements, in execution order -->
    </businessrules>
  </configuration>
  <dragpoints>
    <dragpoint identifier="Accepted" name="[shape].dragpoint1" text="Accepted" toShape="[target]" x="[x]" y="[y]"/>
    <dragpoint identifier="Rejected" name="[shape].dragpoint2" text="Rejected" toShape="[target]" x="[x]" y="[y]"/>
  </dragpoints>
</shape>
```

The display name comes from `userlabel` on the `<shape>` element only — `<businessrules>` has no `name` attribute.

`profileName` is a display cache. `profileId` is authoritative.

Do not emit `index` on `<rule>`. It is accepted and stored but has no effect, and it implies an ordering capability that does not exist.

## Rule Inputs

Every input has an `id`, unique **within its rule** — ids may be reused freely across sibling rules. Conditions and error messages reference inputs by that `id`, and the `<input>` elements form a keyed set rather than a sequence, so their order relative to each other does not matter. The `<rule>` child sequence itself is fixed, though — inputs, then condition, then error message (Gotcha 16). Function inputs carry one further constraint on `id` — see the Map Function section below.

### Profile Field — `xsi:type="BusinessRuleField"`

```xml
<input alias="status" elementKey="3" id="1"
       name="status (Root/Object/status)" taglist="0" xsi:type="BusinessRuleField"/>
```

- `elementKey` — the `key` attribute of the element in the referenced profile. **This is what resolves the field**; the labels play no part.
- `name` — the platform's canonical label, `FieldName (path/through/container/names)`. Owned by the platform: it is written when a field is chosen and left alone otherwise.
- `alias` — a free-text display label owned by the author. Whatever you write survives verbatim. Prefer a short, readable one (`status`, not the full path) — it is the label a human sees in the rule editor.
- `taglist` — instance selection within a repeating element. Emit `0` unless you need occurrence filtering; see Instance Selection below.

Which element `elementKey` names, per profile type:

| Profile type | `profileType` | `elementKey` is the `key` of |
|---|---|---|
| JSON | `profile.json` | `JSONObjectEntry` or `JSONArrayElement` |
| XML | `profile.xml` | `XMLElement` |
| Flat file | `profile.flatfile` | `FlatFileElement` |
| Database | `profile.db` | `DatabaseElement` inside `<DBFields>` — not the `DBStatement` or `DBFields` container key |
| EDI | `profile.edi` | `EdiDataElement` — not the `EdiSegment` or `EdiLoop` key |

### Map Function — `xsi:type="BusinessRuleFunction"`

```xml
<input alias="Upper Status" id="2" xsi:type="BusinessRuleFunction">
  <inputMapping fromElementKey="3" fromName="status (Root/Object/status)" fromTaglist="0" toFunctionInputKey="1"/>
  <FunctionStep cacheEnabled="false" category="String" key="2" name="String To Upper" position="-1" type="String2Upper">
    <Inputs><Input default="" key="1" name="Original String"/></Inputs>
    <Outputs><Output key="2" name="Result"/></Outputs>
    <Configuration/>
  </FunctionStep>
</input>
```

`<FunctionStep>` uses the **same grammar as Map component functions** — see `references/components/map_component_functions.md`, which applies unchanged here. Categories available inline include `ProcessProperty` (`PropertyGet`, `DocumentPropertyGet`, `DefinedProcessPropertyGet`), `String`, `Numeric`, `Lookup` (`CrossRefLookup`), `Scripting`, and `userdefined`.

For `category="userdefined"`, the `FunctionStep` carries `id="[UDF component GUID]"` and its `<Inputs>`/`<Outputs>` mirror the UDF component's own signature. See `references/components/user_defined_function_component.md`.

**CRITICAL: the input's `id` must equal the `key` of its own `<FunctionStep>` child.** In the example above both are `2`. The value is arbitrary and only has to be unique within the rule, but the two attributes must agree. If they disagree the platform accepts the push, deploys, and executes — and every `FunctionConditionInput` reading that input resolves to `null`, in both the condition and the error message. Because the condition expresses the pass state, an emptied output makes the assertion fail, so the document is Rejected with a plausible-looking message full of `null`s. That reads as bad inbound data rather than a misconfigured shape. See Gotcha 2.

**`<inputMapping>`** wires a profile field into a function input:
- `fromElementKey` — source profile element key. `0` means unmapped, and `fromName` is then omitted.
- `toFunctionInputKey` — the `key` of the target `<Input>`. Match on this key, not on sibling order.
- `fromTaglist` — instance selection on the mapping's source, behaving identically to `taglist`. See Instance Selection below.

**`default` on an `<Input>` is a fallback, not a dead initializer.** The precedence is: mapped value if non-blank, otherwise `default`. So an `<Input default="X">` alongside an `<inputMapping>` targeting the same key is a deliberate idiom meaning *"use the field, but if the field is empty use X."*

`position="-1"` and `cacheEnabled="false"` are optional but recommended, matching what the platform emits for functions that have no canvas.

### Instance Selection — `taglist` and `fromTaglist`

`taglist` on an `<input>` and `fromTaglist` on an `<inputMapping>` are the same selector, applied to a field input and to a function input's source respectively. Both take the `listKey` of a `<TagList>` in the referenced profile, restricting the rule to that subset of a repeating element's occurrences.

**Emit `0` unless you specifically need occurrence filtering.** `0` means every occurrence *not* claimed by a TagList — so on a profile that defines none, which is the normal case, it is every occurrence.

Adding a TagList to a profile therefore shrinks the scope of existing rules that read a field in that container with `0`. Nothing errors and no token renders `null`; the rule quietly stops checking the newly-qualified records while reporting clean results for the rest. Revisit those rules and set explicit selectors.

**For `profile.db`, use `0` only.** A non-zero value is accepted on push and deploys cleanly, then aborts the process at initialization with `Unable to extract data from profile, invalid element found. Was looking for element with element key: N and tag list key: M` — on the reference alone, whether or not the profile defines any TagList.

## Conditions

Exactly one `<condition>` per rule, containing at least one comparison.

```xml
<condition operator="and" xsi:type="GroupingCondition">
  <nestedExpression operator="=" xsi:type="SimpleCondition">
    <leftInput deleted="false" id="1" name="status" xsi:type="FieldConditionInput"/>
    <rightInput deleted="false" id="0" name="&quot;ACTIVE&quot;" value="ACTIVE" xsi:type="StaticConditionInput"/>
  </nestedExpression>
</condition>
```

- `GroupingCondition` — `operator` is `and` or `or`; children are `<nestedExpression>` elements.
- `SimpleCondition` — `operator` is a comparison; children are `<leftInput>` and, for binary operators, `<rightInput>`. Unary operators omit `<rightInput>`.
- `<nestedExpression>` is the child element name at **every** level. Nesting is recursive — a nested group is `<nestedExpression xsi:type="GroupingCondition">` containing further `<nestedExpression>` children.
- A `GroupingCondition` takes any number of children, not just two.
- Both sides of a comparison may be `FieldConditionInput`s — field-to-field comparison works, not just field-to-static.
- Wrapping a single comparison in a `GroupingCondition` is a convention, not a requirement: a bare `<condition operator="=" xsi:type="SimpleCondition">` with no wrapper pushes, deploys and evaluates correctly. Wrap anyway to match platform output and to let a single-comparison rule grow without restructuring.

### Condition Inputs

| `xsi:type` | Attributes | Meaning |
|---|---|---|
| `FieldConditionInput` | `id`, `name`, `deleted` | references a `BusinessRuleField` input by `id` |
| `FunctionConditionInput` | `id`, `name`, `outputId`, `deleted` | references a `BusinessRuleFunction` input by `id`; `outputId` selects which `<Output key=>` to read |
| `StaticConditionInput` | `id="0"`, `name`, `value`, `deleted` | a literal — `value` holds the raw literal, `name` the same value in escaped double quotes |

`(id, outputId)` is the authoritative reference pair. The `name` attribute here caches the **referenced input's `alias`** — not the field path — and goes stale as soon as that alias is edited without every reference being rewritten. Never treat it as a lookup key.

A `StaticConditionInput` is legal on either side. `deleted="false"` is the default and may be omitted, but emit it to match platform output.

### Nested Groups — Optional-Override Idiom

*"If the flag is unset, pass; if set, require a match."* Useful for feature-flag and test-mode gates:

```xml
<condition operator="or" xsi:type="GroupingCondition">
  <nestedExpression operator="and" xsi:type="GroupingCondition">
    <nestedExpression operator="is not empty" xsi:type="SimpleCondition">
      <leftInput deleted="false" id="2" name="Flag" outputId="1" xsi:type="FunctionConditionInput"/>
    </nestedExpression>
    <nestedExpression operator="=" xsi:type="SimpleCondition">
      <leftInput deleted="false" id="1" name="channel" xsi:type="FieldConditionInput"/>
      <rightInput deleted="false" id="2" name="Flag" outputId="1" xsi:type="FunctionConditionInput"/>
    </nestedExpression>
  </nestedExpression>
  <nestedExpression operator="is empty" xsi:type="SimpleCondition">
    <leftInput deleted="false" id="2" name="Flag" outputId="1" xsi:type="FunctionConditionInput"/>
  </nestedExpression>
</condition>
```

## Operators

Word operators are literal lowercase phrases, spaces included — not camelCase and not symbolic codes.

| Operator | Arity | Notes |
|---|---|---|
| `=` `!=` | binary | equality |
| `&lt;` `&gt;` `&lt;=` `&gt;=` | binary | **numeric** comparison — must be XML-escaped in the attribute |
| `contains` `does not contain` | binary | left is the value inspected, right is the value searched for |
| `starts with` | binary | left begins with right |
| `is empty` `is not empty` | unary | `<leftInput>` only, no `<rightInput>` |

**The four symbolic operators compare numerically when both operands parse as numbers.** The profile's declared `dataType` is irrelevant — a `character` field holding `"9"` compares as 9, so `qty < "10"` passes for `9` and fails for `100`. You do not need a number-typed profile to write numeric rules, and you cannot force lexical ordering by declaring a field as character.

**CRITICAL: when either operand does not parse as a number, they fall back to a lexical string comparison.** They do not error, and they do not evaluate false. `note > "10"` where `note` is `"Hello World"` evaluates **true**, because `"H"` sorts after `"1"`.

This makes a numeric rule **fail open on dirty data**, which is the opposite of what a validation step is for. A rule written `amount > "0"` accepts a document whose `amount` is the string `"unknown"`. Roughly half of all such comparisons will pass, depending only on where the garbage sorts against the literal.

To validate a numeric field safely, pair the comparison with a separate rule that establishes the value is numeric at all — for example a `Numeric` category function whose output the condition checks — rather than relying on the comparison to reject non-numbers.

`<=` and `>=` include the equality case.

`is empty` tests for an absent value. A `StaticConditionInput` with `value=""` matches both a present-but-empty field and a genuinely absent one, so the two forms are interchangeable in practice; `is empty` states the intent more clearly.

Because these operators must appear inside an XML attribute, the symbolic forms are written `operator="&lt;"`, `operator="&gt;"`, `operator="&lt;="`, `operator="&gt;="`.

## Error Messages

Exactly one per rule, emitted when the condition evaluates FALSE.

```xml
<errorMessage content="Status must be ACTIVE but was &quot;{1}&quot;.">
  <input index="1">
    <input deleted="false" id="1" name="status" xsi:type="FieldConditionInput"/>
  </input>
</errorMessage>
```

- `content` is an **attribute**, so every XML special character must be escaped.
- Tokens are `{1}`, `{2}`, … and are **1-based**.
- Note the **doubled element name**: an outer `<input index="N">` wrapper containing exactly one inner `<input xsi:type="...">` using the condition-input grammar.
- **`{N}` binds to the wrapper whose `index` attribute is `N`, not to the Nth wrapper element.** This is the opposite of the rule for `<parametervalue>` elements everywhere else in the skill, where placeholders map by element order and keys are ignored — see `references/guides/parameter_value_types.md`. Wrapper order is free; the `index` value is what matters.
- A token with no matching wrapper behaves in one of two ways, neither of which errors. If its number falls **within** the declared range — a gap, e.g. `{3}` when wrappers exist for 1, 2 and 4 — it renders **`null`**. If it is **above** the highest declared index — `{9}` in that same message — it renders **literally** as those characters. So a mis-numbered token in the middle of a message is indistinguishable from the failures in Diagnosing `null` below.
- A token may inject a profile field (`FieldConditionInput`) or a function output (`FunctionConditionInput` with `outputId`).
- A message token may select a **different** `outputId` of the same function input than the condition used, including outputs the condition never reads — so one output can drive the pass/fail decision while others enrich the message. This is the practical reason to build multi-output functions.
- `outputId` is the target `<Output>`'s `key`, **not** a 1-based ordinal. An output declared `<Output key="7">` is read with `outputId="7"`; reading it as `outputId="1"` yields `null`. The two coincide only when outputs happen to be keyed 1, 2, 3.

### The 10,000-Character Limit Drops Entries Silently

The limit is per document, across the whole aggregated failure document — not per message.

Entries are appended in rule order while the document stays under the ceiling. **An entry that would exceed it is skipped entirely** — not truncated — and the root element gains a `skippedErrorsCount` attribute:

```xml
<business_rule_failures skippedErrorsCount="1">
```

A single message longer than the ceiling can therefore never appear at all. **Nothing is written to the process log.** So one verbose early rule can silently push later rules' failures out of the report, and the only evidence is an attribute a consumer has to look for.

Any downstream profile or string comparison built against the root element must tolerate that attribute being present.

### Single Quotes Are Escape Characters

This applies to the literal message text only, never to substituted `{N}` data — a quote arriving in the data passes through untouched.

- A lone `'` is stripped: `today's date` renders as `todays date`.
- Two consecutive quotes render as one: `today''s date` renders as `today's date`.
- **An unclosed quote escapes the rest of the message.** In `{1} o'clock {2}`, the `{1}` before the quote substitutes normally, then `{2}` renders as the literal four characters `{2}`.

**Double every apostrophe in literal message text.** An odd number of single quotes silently disables every token to its right — no error, no warning.

## Repeating Elements

A rule whose input references a repeating element executes **once per occurrence**, producing one failure entry per failing occurrence. That is the behavior with `taglist="0"` on an ordinary profile; if the profile defines TagLists, see Instance Selection above.

A `{N}` token resolves to the **current** occurrence's value, and failures appear in source order.

This applies to function inputs too, not just field inputs: a repeating element feeding a function through `<inputMapping>` invokes the function **once per occurrence** with that occurrence's value — not once with the first value, and not once with a concatenation. Worth watching for an expensive function (a Lookup or Connector Call) sourced from a large repeating element, since the per-occurrence cost is easy to author unintentionally.

**Always include a `{N}` token echoing the offending value in a rule that targets a repeating element.** Without one, a document with three failing occurrences produces three byte-identical error lines and the consumer cannot tell which entries were bad. There is no way to report the occurrence *index* — only its value.

## Reading the Failure Message

Rejected documents carry the aggregate as a tracked property. Exact format:

```xml
<business_rule_failures>
   <business_rule_failure rule="Status must be ACTIVE">Status must be ACTIVE.</business_rule_failure>
   <business_rule_failure rule="Qty is required">Qty is required.</business_rule_failure>
</business_rule_failures>
```

Three spaces indent each entry, there is no XML declaration, and the document ends with a trailing newline. `rule=` is always present and carries the rule's `name`. On overflow the root element also carries `skippedErrorsCount` (see above).

The engine applies position-aware XML escaping — `<`, `>`, `&` are escaped in element text, and `"` is escaped in the `rule=` attribute — so arbitrary rule names and message text cannot break the document. A downstream XML profile can parse it safely.

It is a **tracked** (`meta.base.*`) property, not a dynamic document property, so it is read with `valueType="track"`. See `references/guides/parameter_value_types.md` for the full parameter value type reference, substitution rules, and `trackparameter` GUI display requirements:

```xml
<parametervalue key="0" valueType="track">
  <trackparameter defaultValue="" propertyId="meta.base.businessrulesmessage"
                  propertyName="Base - Business Rules Result Message"/>
</parametervalue>
```

In the GUI this is *Document Property → Meta Information → Base → Business Rules Result Message*.

**On the Accepted path the property is absent**, and `{N}` substitution renders it as the literal string `null` — not an empty string and not an empty `<business_rule_failures/>` envelope. A `defaultValue=""` on the `<trackparameter>` does not normalize this. Guard the Accepted path before handing the value to an XML parser.

**The process log flattens the newlines to spaces**, so the exact format above cannot be verified from a log. To recover the value byte-exactly, route it through a Message step (`msgTxt` of `{1}`), then a Data Process Base64 Encode, then a Notify — and decode locally. **Strip all whitespace from the logged Base64 before decoding**: the log inserts a space every 76 characters into the encoded text itself, so decoding it verbatim fails. Bracketing the token with sentinel characters in the Message step makes the boundaries easy to cut.

### Turning Failures Into a Bulleted List

The recipe for a human-readable summary:

1. **Message** step with `msgTxt` of just `{1}` bound to the tracked property — promotes the metadata to the document payload so downstream shapes can parse it.
2. **Data Process** step, Split Documents, against an XML profile modeling `business_rule_failures/business_rule_failure` (use `maxOccurs="-1"` on the inner element) — one document per failure.
3. **Map** from that XML profile to a single-field flat file profile — strips the XML wrapper to bare message text.
4. **Message** step with `combined="true"` and `msgTxt` of `* {1}` using `valueType="current"` — concatenates all documents into one bulleted string.
5. **Set Properties** to persist the result for downstream use.

## Building Instructions

### Step 1: Have the Profile First
`elementKey` must carry the real `key` values from the referenced profile, so the profile must exist before the shape references it. If you authored the profile you already know its keys; if it came from the platform, pull it and read them rather than assuming.

### Step 2: Declare All Inputs
Add every `<input>` the rule needs. Assign `id` values unique within the rule — and for a function input, set `id` equal to its `<FunctionStep>`'s `key`.

### Step 3: Write the Condition as the Pass State
Express what must be TRUE. Wrap in a `GroupingCondition` even for one comparison.

### Step 4: Write the Error Message
Describe the failure. Double any apostrophes. Add `<input index="N">` wrappers for each `{N}` token.

### Step 5: Connect Both Dragpoints
`Accepted` and `Rejected`, capitalized, with `identifier` and `text` matching.

### Step 6: Verify the Root Namespace
Confirm `xmlns:xsi` is declared on `<bns:Component>`.

### Step 7: Test Both Directions
Exercise at least one accepted and one rejected document. Push and deploy success prove nothing about this shape — several malformed configurations deploy cleanly and only fail at request time.

## Diagnosing `null`

`null` is this step's universal symptom and it has five distinct causes. None of them errors or logs anything, so the string alone tells you almost nothing — work down this list.

| Where you see it | Cause | Distinguishing check |
|---|---|---|
| A `{N}` token in a failure message | The referenced field is present but **empty** | Look at the source data — this one is not a defect |
| A `{N}` token | The token number is a **gap** within the declared range | Compare every token in `content` against the `index` values actually present |
| Every token reading one function | The function input's `id` ≠ its `<FunctionStep>`'s `key` | Compare those two attributes; also expect a wrongly-Rejected document (Gotcha 2) |
| One token reading a function | `outputId` names no real `<Output key=>` on that function | Check it is the output's `key`, not its position |
| The whole tracked property, read anywhere | The document was **Accepted**, so the property is absent | Check which path the document took |

The first two are read-only cosmetic problems. The third silently produces a **wrong verdict** — a document Rejected for a fabricated reason — so rule it in or out first.

## Common Gotchas

1. **CRITICAL: every `<rule>` must have an `<errorMessage>`.** The platform API silently accepts and deploys a rule without one; the failure surfaces only at execution, as a bare `NullPointerException` on the document — no rule name, no shape detail, no cause. It is latent, firing only when data actually violates that rule, so it can sit in production for months and then look like intermittent data corruption rather than a configuration defect. If a rule genuinely has nothing to say, emit `<errorMessage content="Validation failed."/>` rather than omitting it.
2. **CRITICAL: a `BusinessRuleFunction` input's `id` must equal its `<FunctionStep>`'s `key`.** Mismatch is accepted on push, deploys, and executes; every token reading that function then renders `null`, and the emptied output flunks the pass-state condition, so the document is Rejected for a fabricated reason. **The rule editor shows nothing wrong** — it renders as a perfectly normal rule — so this is invisible at both design time and request time. `null` alone is not diagnostic; see Diagnosing `null` above for the five causes.
3. **CRITICAL: a numeric comparison against non-numeric data falls back to lexical string comparison and can pass.** `amount > "0"` accepts `"unknown"`. See Operators — this is a fail-open on exactly the input a validation step exists to catch.
4. **A rule with no condition, or an empty `GroupingCondition`, aborts the whole process at initialization** with `"<rule name>" is invalid.` followed by `Rule doesn't contain any conditions to check`. The message names the offending rule, which matters in a shape with thirty of them. Every rule needs exactly one condition containing at least one comparison.
5. **A `BusinessRuleFunction` input without its `<FunctionStep>` child aborts the process at initialization**, even if no condition references that input. Every declared function input is validated eagerly — never emit a placeholder.
6. **Several malformed configurations leave the shape unrepairable through the GUI.** A rule with no `<condition>` makes the whole Business Rules step refuse to open from the canvas; a function input with no `<FunctionStep>` lets the step open but not that rule; the prohibited condition types (Gotcha 14) open with an empty Conditions box and no button to add one. In each case the stored component is intact and unharmed — opening it writes nothing — but a human cannot fix it without API access. Treat these as worse than a request-time failure, not equivalent to one.
7. **Adding a TagList to a profile silently shrinks the scope** of every existing rule reading a field inside that container with `taglist="0"` — those rules stop checking the newly-qualified records and report clean results for the rest. Nothing errors and no token goes `null`. Revisit affected rules and set explicit selectors. On a `profile.db` input, a non-zero `taglist` aborts the process at initialization; use `0` there.
8. **`Unable to read message body` on push means malformed XML**, most often a missing `xmlns:xsi` on the root element. It names nothing useful. An error that *names an element* means well-formed but schema-invalid — a different problem entirely.
9. **Unescaped symbolic operators break the XML.** Write `operator="&lt;"`, never `operator="<"`.
10. **An odd number of single quotes in message text silently kills every `{N}` token to its right.** Double every apostrophe.
11. **Do not invert the condition to match the error message's wording.** The condition is the pass state.
12. **A profile-parse failure routes to neither path.** Add a Try/Catch if input may be malformed.
13. **On the Accepted path the failure property is `null`, not empty XML.** Guard before parsing.
14. **Never use `NegationCondition`, `ExclusiveDisjunctionCondition`, `ImplicationCondition`, or `UniquenessCondition`.** The rule editor never offers them — it presents only `and` and `or` — so these are purely an API-authoring hazard. Each has its own required child grammar (`<proposition>`, `<leftOperand>`/`<rightOperand>`, `<antecedent>`/`<consequent>`, `<nestedExpression>`) and takes no `operator` attribute; shaped wrongly they are rejected on push, and shaped correctly they deploy cleanly and then abort the process at initialization with `Unknown condition type`. Either way the rule becomes uneditable in the GUI. `and`/`or` over the operators above is the step's entire logic vocabulary. Express NOT with the negating operator (`NOT (x = v)` is `x != v`); split anything more complex into separate rules.
15. **`profileName` and the `name` on a condition or message input are caches** and may be stale — the latter holds the referenced input's `alias`, so editing an alias leaves stale copies behind. `profileId`, `elementKey`, and `(id, outputId)` are authoritative. Preserve cosmetic values verbatim on a round-trip rather than "fixing" them.
16. **The `<rule>` child sequence is schema-enforced**: all `<input>` elements, then `<condition>`, then `<errorMessage>`. Order among the inputs is free, but an `<input>` placed after `<errorMessage>` fails push with `cvc-complex-type.2.4.d`.

## XML Reference

Two rules — a static comparison with a parameterized message, and a numeric comparison:

```xml
<shape image="businessrules_icon" name="shape3" shapetype="businessrules" userlabel="Validate Order" x="498.0" y="46.0">
  <configuration>
    <businessrules profileId="423e014b-52c7-42e4-a945-bba0b04680db" profileName="j.Order" profileType="profile.json">
      <rule key="1" name="Status must be ACTIVE">
        <input alias="status" elementKey="3" id="1" name="status (Root/Object/status)" taglist="0" xsi:type="BusinessRuleField"/>
        <condition operator="and" xsi:type="GroupingCondition">
          <nestedExpression operator="=" xsi:type="SimpleCondition">
            <leftInput deleted="false" id="1" name="status" xsi:type="FieldConditionInput"/>
            <rightInput deleted="false" id="0" name="&quot;ACTIVE&quot;" value="ACTIVE" xsi:type="StaticConditionInput"/>
          </nestedExpression>
        </condition>
        <errorMessage content="Status must be ACTIVE but was &quot;{1}&quot;.">
          <input index="1">
            <input deleted="false" id="1" name="status" xsi:type="FieldConditionInput"/>
          </input>
        </errorMessage>
      </rule>
      <rule key="2" name="Quantity below limit">
        <input alias="qty" elementKey="4" id="1" name="qty (Root/Object/qty)" taglist="0" xsi:type="BusinessRuleField"/>
        <condition operator="and" xsi:type="GroupingCondition">
          <nestedExpression operator="&lt;=" xsi:type="SimpleCondition">
            <leftInput deleted="false" id="1" name="qty" xsi:type="FieldConditionInput"/>
            <rightInput deleted="false" id="0" name="&quot;100&quot;" value="100" xsi:type="StaticConditionInput"/>
          </nestedExpression>
        </condition>
        <errorMessage content="Quantity {1} exceeds the limit of 100.">
          <input index="1">
            <input deleted="false" id="1" name="qty" xsi:type="FieldConditionInput"/>
          </input>
        </errorMessage>
      </rule>
    </businessrules>
  </configuration>
  <dragpoints>
    <dragpoint identifier="Accepted" name="shape3.dragpoint1" text="Accepted" toShape="shape4" x="707.0" y="54.0"/>
    <dragpoint identifier="Rejected" name="shape3.dragpoint2" text="Rejected" toShape="shape6" x="707.0" y="254.0"/>
  </dragpoints>
</shape>
```

## Best Practices

### Naming Rules as Assertions
Phrase rule names as the pass state — "Message is empty", "Status must be ACTIVE", "Event is not a retry attempt". The name appears in the `rule=` attribute of every failure, so it doubles as the failure label, and it keeps the canvas self-documenting.

### Position and Dependencies
The shape can sit anywhere a document is available, including as the first shape after a passthrough Start. Its only requirement is a document that parses against the declared profile.

It is not self-contained: `profileId`, a `crossRefTableId` on a Lookup function, and a UDF component `id` are all real component references. Packaging the process picks them up automatically, so no separate deploy step is needed — but they must exist before the shape references them, and a dependency scan has to resolve them (see `references/guides/pulling_components.md`).

### Validate Generated XML Locally
Because push and deploy accept configurations that fail at request time, check generated XML before pushing:
- every `<rule>` has exactly one `<condition>` containing at least one comparison
- every `<rule>` has exactly one `<errorMessage>`
- every `BusinessRuleFunction` input has a `<FunctionStep>`, **and its `id` equals that `<FunctionStep>`'s `key`**
- every condition/message input `id` resolves to a declared input in the same rule, and `outputId` is present exactly when the target is a function
- every `outputId` matches an actual `<Output key=>` on the target function, not its position in the list
- every `{N}` token in a message has an `<input index="N">` wrapper carrying that exact index
- each `<rule>` orders its children inputs → condition → error message
- unary operators have no `<rightInput>`
- symbolic operators are XML-escaped
- `xmlns:xsi` is declared on the root element
- no symbolic comparison is relied on to reject non-numeric data
