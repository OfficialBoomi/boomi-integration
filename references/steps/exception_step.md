# Exception Step

## Contents
- Purpose
- Configuration Structure
- Attributes
- Parameters
- XML Reference

## Purpose
Terminates document execution and generates a user-defined error message reported on the Process Reporting page.

**Use when:**
- You want a certain circumstance (i.e. a document going down a particular path) to halt processing, either for that individual document or (importantly) for a whole process. 
- You want to have additional flagging, custom error messages, and human-reporting visibility on a given situation. 

An exception path is often used after an 'unhappy path' decision or catch.

## Configuration Structure
```xml
<shape image="exception_icon" name="[shapeName]" shapetype="exception" userlabel="[label]" x="[x]" y="[y]">
  <configuration>
    <exception stopProcessReturnSingleDoc="false" stopsingledoc="[true|false]" title="[title]">
      <exMessage>[Error message with {1} placeholders]</exMessage>
      <exParameters>
        <parametervalue key="[index]" usesEncryption="false" valueType="[type]">
          <!-- Value configuration based on type -->
        </parametervalue>
      </exParameters>
    </exception>
  </configuration>
  <dragpoints/>
</shape>
```

Exception is a terminal shape — `<dragpoints/>` is always empty/self-closing.

## Attributes

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `stopsingledoc` | boolean | `false` | `true`: only the document that reaches the Exception step fails; other documents in the batch continue processing normally. `false`: the process terminates immediately and remaining documents' processing paths are abandoned (they are not individually "marked as failed" — they simply never execute). |
| `stopProcessReturnSingleDoc` | boolean | `false` | Present in platform XML. Runtime behavior unconfirmed — do not make behavioral claims about this attribute. |
| `title` | string | | Descriptive title for the exception configuration. Appears in the GUI. |

## Parameters
Exception message parameters follow the same rules as Notify and Message steps:
- Substitution is by XML element order, not `key` attribute
- Same `valueType` options: `static`, `track`, `process`, `current`, `date`, `profile`
- Same `<trackparameter>` GUI display requirements (`propertyName` and `defaultValue` attributes)
- Same single-quote escaping behavior

See `references/steps/notify_step.md` for full parameter and escaping details.

## XML Reference

### Fail Single Document
```xml
<shape image="exception_icon" name="shape2" shapetype="exception" userlabel="Order Validation Failed" x="320.0" y="96.0">
  <configuration>
    <exception stopProcessReturnSingleDoc="false" stopsingledoc="true" title="Order Validation Failed">
      <exMessage>Order {1} failed validation</exMessage>
      <exParameters>
        <parametervalue key="0" usesEncryption="false" valueType="track">
          <trackparameter defaultValue="" propertyId="dynamicdocument.DDP_ORDER_ID"
                          propertyName="Dynamic Document Property - DDP_ORDER_ID"/>
        </parametervalue>
      </exParameters>
    </exception>
  </configuration>
  <dragpoints/>
</shape>
```

### Fail Entire Process
```xml
<shape image="exception_icon" name="shape3" shapetype="exception" userlabel="Critical Failure" x="320.0" y="256.0">
  <configuration>
    <exception stopProcessReturnSingleDoc="false" stopsingledoc="false" title="Critical Failure">
      <exMessage>Processing halted: {1}</exMessage>
      <exParameters>
        <parametervalue key="0" usesEncryption="false" valueType="static">
          <staticparameter staticproperty="missing required configuration"/>
        </parametervalue>
      </exParameters>
    </exception>
  </configuration>
  <dragpoints/>
</shape>
```