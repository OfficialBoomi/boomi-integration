# Shape Notes Reference

## Contents
- Purpose
- Limitations
- XML Structure
- Note Element
- Supported HTML Formatting
- Example

## Purpose

Shape notes add documentation visible in the Boomi GUI to process shapes. Notes appear as annotations that other developers can see when viewing or editing the process canvas.

**Use sparingly and only by explicit request.** These notes can be perceived as "clutter" and can contain outdated information if not carefully curated and managed. Do not proactively add shape notes unless the user specifically requests documentation on shapes.

## Limitations

- **~300 character limit** per note - keep notes as brief as possible
- **One note per shape** - multiple notes on a single shape are not supported

## XML Structure

The `<stepnotes>` element is a child of `<shape>`, placed after `<dragpoints>`:

```xml
<shape image="message_icon" name="shape33" shapetype="message" userlabel="My Step" x="816.0" y="192.0">
  <configuration>...</configuration>
  <dragpoints>...</dragpoints>
  <stepnotes>
    <note title="Note Title">HTML content (XML-escaped)</note>
  </stepnotes>
</shape>
```

## Note Element

| Attribute | Description |
|-----------|-------------|
| `title` | The note's title displayed in the GUI. Special characters must be XML-escaped (e.g., `&quot;` for quotes). |

The element content is HTML that must be XML-escaped.

## Supported HTML Formatting

| Format | HTML | XML-Escaped |
|--------|------|-------------|
| Paragraph | `<p>text</p>` | `&lt;p&gt;text&lt;/p&gt;` |
| Bold | `<strong>text</strong>` | `&lt;strong&gt;text&lt;/strong&gt;` |
| Italics | `<em>text</em>` | `&lt;em&gt;text&lt;/em&gt;` |
| Underline | `<u>text</u>` | `&lt;u&gt;text&lt;/u&gt;` |
| Strikethrough | `<del>text</del>` | `&lt;del&gt;text&lt;/del&gt;` |
| Link | `<a href="url">text</a>` | `&lt;a href="url"&gt;text&lt;/a&gt;` |
| Indentation | `<p style="margin-left: 25px">text</p>` | `&lt;p style="margin-left: 25px"&gt;text&lt;/p&gt;` |
| Ordered List | `<ol><li>item</li></ol>` | `&lt;ol&gt;&lt;li&gt;item&lt;/li&gt;&lt;/ol&gt;` |
| Unordered List | `<ul><li>item</li></ul>` | `&lt;ul&gt;&lt;li&gt;item&lt;/li&gt;&lt;/ul&gt;` |

## Example

Adding a simple note to a Message step:

```xml
<shape image="message_icon" name="shape33" shapetype="message" userlabel="Clear Document" x="816.0" y="192.0">
  <configuration>
    <message combined="false">
      <msgTxt/>
      <msgParameters/>
    </message>
  </configuration>
  <dragpoints>
    <dragpoint name="shape33.dragpoint1" toShape="shape12" x="1008.0" y="168.0"/>
  </dragpoints>
  <stepnotes>
    <note title="Why this step exists">&lt;p&gt;This Message step clears the document body before making the REST call because the GET operation does not require a request body.&lt;/p&gt;</note>
  </stepnotes>
</shape>
```
