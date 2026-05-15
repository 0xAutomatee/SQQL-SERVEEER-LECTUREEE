# SQL Dynamic Pivot Practice README

## Purpose

This README explains each SQL practice query step by step.  
Main goal: understand how to build **dynamic columns**, use `STRING_AGG`, `QUOTENAME`, `CASE`, `SUM`, `JOIN`, `TRY_CAST`, and later combine these logics into a dynamic Credit Applied Sheet.

---

# Source Tables Used

## 1. `dbo.step_01a_in_sheet`

This table contains invoice references.

Example:

| ref |
|---|
| IN#5767636 |
| IN#5777129 |

## 2. `dbo.step_02_po_details`

This table contains PO/payment detail data.

Example:

| invoice_number | qxc | cr_issue |
|---|---:|---|
| IN#5767636 | 100.00 | CR#515461 |
| IN#5767636 | 50.00 | CR#515461 |
| IN#5777129 | 200.00 | CR#515630 |

## 3. `dbo.step_01a_cr_sheet`

This table contains credit references and credit amounts.

Example:

| ref | pay_day |
|---|---:|
| CR#515461 | -150.00 |
| CR#515630 | -200.00 |

---

# Basic Dynamic Column Concepts

---

## Query 01: Combine all invoice refs into one text line

```sql
SELECT STRING_AGG(ref, ',') 
FROM dbo.step_01a_in_sheet;
```

### What it does

`STRING_AGG` joins many row values into one string.

### Example output

```text
IN#5767636,IN#5777129
```

### Core logic

```sql
STRING_AGG(column_name, separator)
```

Means:

> Take all values from `column_name` and join them using `separator`.

---

## Query 02: Make invoice refs safe as SQL column names

```sql
SELECT 
    ref,
    QUOTENAME(ref) AS safe_column
FROM dbo.step_01a_in_sheet;
```

### What it does

`QUOTENAME(ref)` adds square brackets around invoice numbers.

### Example output

| ref | safe_column |
|---|---|
| IN#5767636 | [IN#5767636] |
| IN#5777129 | [IN#5777129] |

### Why this is needed

Invoice number has special character `#`.

SQL column names like this:

```sql
IN#5767636
```

can cause problems.

Safe version:

```sql
[IN#5767636]
```

---

## Query 03: Store dynamic columns inside variable

```sql
DECLARE @cols NVARCHAR(MAX);

SELECT @cols =
    STRING_AGG(QUOTENAME(ref), ',')
    WITHIN GROUP (ORDER BY ref)
FROM step_01a_in_sheet;

PRINT @cols;
```

### What it does

Creates a text list of safe invoice columns.

### Example output

```sql
[IN#5767636],[IN#5777129]
```

### Important parts

```sql
DECLARE @cols NVARCHAR(MAX);
```

Creates a variable.

```sql
STRING_AGG(QUOTENAME(ref), ',')
```

Combines all invoice refs with brackets.

```sql
WITHIN GROUP (ORDER BY ref)
```

Sorts invoice refs before joining them.

```sql
PRINT @cols;
```

Shows the result.

---

# CASE Logic

---

## Query 04: Check if invoice number matches one invoice

```sql
SELECT
    invoice_number,
    qxc,
    CASE
        WHEN invoice_number = 'IN#5767636'
        THEN 'MATCHED'
        ELSE 'NOT MATCHED'
    END AS status
FROM dbo.step_02_po_details;
```

### What it does

Checks each row:

- If invoice is `IN#5767636`, show `MATCHED`
- Otherwise show `NOT MATCHED`

### Example output

| invoice_number | qxc | status |
|---|---:|---|
| IN#5767636 | 100.00 | MATCHED |
| IN#5777129 | 200.00 | NOT MATCHED |

### Core syntax

```sql
CASE
    WHEN condition THEN result
    ELSE other_result
END
```

---

## Query 05: Sum amount only for one invoice

```sql
SELECT
SUM(
    CASE
        WHEN invoice_number = 'IN#5767636'
        THEN qxc
        ELSE 0
    END
) AS total_for_invoice
FROM dbo.step_02_po_details;
```

### What it does

Adds `qxc` only where invoice number is `IN#5767636`.

### Example

| invoice_number | qxc |
|---|---:|
| IN#5767636 | 100 |
| IN#5767636 | 50 |
| IN#5777129 | 200 |

Output:

| total_for_invoice |
|---:|
| 150 |

### Core logic

```sql
CASE WHEN invoice_number = 'IN#5767636'
THEN qxc
ELSE 0
END
```

Means:

> Pick amount for matching invoice, otherwise use 0.

Then `SUM()` adds all values.

---

## Query 06: Group total by invoice number

```sql
SELECT
    invoice_number,
    SUM(qxc) AS total_amount
FROM dbo.step_02_po_details
GROUP BY invoice_number;
```

### What it does

Gives total amount for each invoice.

### Example output

| invoice_number | total_amount |
|---|---:|
| IN#5767636 | 150.00 |
| IN#5777129 | 200.00 |

### Core logic

```sql
GROUP BY invoice_number
```

Means:

> Make one group for each invoice number.

---

# Safe Number Conversion

---

## Query 07: Convert `qxc` into decimal

```sql
SELECT
    qxc,
    TRY_CAST(qxc AS decimal(18,0)) AS converted_value
FROM dbo.step_02_po_details;
```

### What it does

Converts `qxc` into a number.

### Why use `TRY_CAST`

If value is bad text, `TRY_CAST` gives `NULL` instead of error.

Example:

| qxc | converted_value |
|---|---:|
| 100.50 | 101 |
| abc | NULL |

Note: `decimal(18,0)` has 0 digits after decimal, so it rounds/removes decimal scale.

---

## Query 08: Convert safely and replace bad values with 0

```sql
SELECT
    qxc,
    ISNULL(TRY_CAST(qxc AS decimal(18,2)),0) AS safe_amount
FROM dbo.step_02_po_details;
```

### What it does

Converts `qxc` to decimal with 2 decimal places.

If conversion fails, it returns 0.

### Example

| qxc | safe_amount |
|---|---:|
| 100.50 | 100.50 |
| abc | 0.00 |
| NULL | 0.00 |

### Core logic

```sql
ISNULL(value, 0)
```

Means:

> If value is NULL, replace with 0.

---

# JOIN Logic

---

## Query 09: LEFT JOIN credit sheet with PO details

```sql
SELECT
    c.ref,
    p.invoice_number,
    p.qxc
FROM dbo.step_01a_cr_sheet c
LEFT JOIN dbo.step_02_po_details p
ON p.cr_issue = c.ref;
```

### What it does

Shows all credits from `c`.

If matching PO data exists, it shows invoice and qxc.

### Important

```sql
LEFT JOIN
```

Means:

> Keep all rows from left table, even if right table has no match.

### Example output

| ref | invoice_number | qxc |
|---|---|---:|
| CR#515461 | IN#5767636 | 100.00 |
| CR#515630 | IN#5777129 | 200.00 |
| CR#999999 | NULL | NULL |

---

## Query 10: FULL OUTER JOIN credit sheet with PO details

```sql
SELECT
    c.ref,
    p.invoice_number,
    p.qxc
FROM dbo.step_01a_cr_sheet c
FULL OUTER JOIN dbo.step_02_po_details p
ON p.cr_issue = c.ref;
```

### What it does

Shows:

- Credits that have PO match
- Credits that do not have PO match
- PO rows that do not have credit match

### Important

```sql
FULL OUTER JOIN
```

Means:

> Keep all rows from both tables.

---

# Dynamic Column List

---

## Query 11: Create dynamic invoice columns

```sql
SELECT
STRING_AGG(
    QUOTENAME(ref),
    ','
) AS dynamic_columns
FROM dbo.step_01a_in_sheet;
```

### What it does

Creates comma-separated safe invoice columns.

### Example output

```sql
[IN#5767636],[IN#5777129]
```

---

## Query 12: Store dynamic columns in variable

```sql
DECLARE @cols NVARCHAR(MAX);

SELECT @cols =
STRING_AGG(
    QUOTENAME(ref),
    ','
)
FROM dbo.step_01a_in_sheet;

PRINT @cols;
```

### What it does

Same logic as Query 11, but stores result in `@cols`.

---

# Dynamic SQL

---

## Query 13: Build SQL query text dynamically

```sql
DECLARE @cols NVARCHAR(MAX);
DECLARE @sql NVARCHAR(MAX);

SELECT @cols = STRING_AGG(QUOTENAME(ref), ',')
FROM dbo.step_01a_in_sheet;

SET @sql = '
    SELECT ' + @cols + '
    FROM dbo.step_02_po_details
';

PRINT @cols;
PRINT @sql;
```

### What it does

Builds query as text.

### Example generated SQL

```sql
SELECT [IN#5767636],[IN#5777129]
FROM dbo.step_02_po_details
```

### Important note

This query only works if these are real columns in `step_02_po_details`.

If invoice numbers are values inside `invoice_number`, then you need `SUM(CASE...)` dynamic logic instead.

---

# Manual Pivot Logic

---

## Query 14: Manual invoice columns using SUM + CASE

```sql
SELECT
SUM(
CASE
WHEN invoice_number='IN#5767636'
THEN qxc
ELSE 0
END
) AS [IN#5767636],

SUM(
CASE
WHEN invoice_number='IN#5777129'
THEN qxc
ELSE 0
END
) AS [IN#5777129]

FROM dbo.step_02_po_details;
```

### What it does

Turns invoice values into columns manually.

### Example source data

| invoice_number | qxc |
|---|---:|
| IN#5767636 | 100 |
| IN#5767636 | 50 |
| IN#5777129 | 200 |

### Output

| IN#5767636 | IN#5777129 |
|---:|---:|
| 150 | 200 |

### This is the base idea for dynamic pivot

Manual:

```sql
SUM(CASE WHEN invoice_number='IN#5767636' THEN qxc ELSE 0 END) AS [IN#5767636]
```

Dynamic version will generate this code automatically for all invoices.

---

# Text Cleaning and Escaping

---

## Query 15: Escape single quotes safely

```sql
SELECT
    ref,
    REPLACE(ref,'''','''''') AS fixed_ref
FROM dbo.step_01a_in_sheet;
```

### What it does

Replaces one single quote `'` with two single quotes `''`.

### Why

In dynamic SQL, single quote can break your query.

Example:

```text
IN#57'636
```

Needs to become:

```text
IN#57''636
```

---

## Query 16: Trim spaces from invoice number

```sql
SELECT
    '[' + invoice_number + ']' AS original,
    '[' + LTRIM(RTRIM(invoice_number)) + ']' AS cleaned
FROM dbo.step_02_po_details;
```

### What it does

Removes extra spaces from left and right side.

### Example

| original | cleaned |
|---|---|
| [ IN#5767636 ] | [IN#5767636] |

### Core functions

```sql
LTRIM()
```

Removes left spaces.

```sql
RTRIM()
```

Removes right spaces.

---

# Credit Amount Logic

---

## Query 17: Make credit amount positive

```sql
SELECT
    pay_day,
    ABS(pay_day) AS positive_value
FROM dbo.step_01a_cr_sheet;
```

### What it does

Turns negative value into positive value.

### Example

| pay_day | positive_value |
|---:|---:|
| -150.00 | 150.00 |

### Safer version

If `pay_day` is text, use:

```sql
SELECT
    pay_day,
    ABS(TRY_CAST(pay_day AS decimal(18,2))) AS positive_value
FROM dbo.step_01a_cr_sheet;
```

---

# Key Building

---

## Query 18: Combine invoice and credit into one key

```sql
SELECT
    CONCAT(invoice_number, cr_issue) AS combined_key
FROM dbo.step_02_po_details;
```

### What it does

Joins invoice number and credit number together.

### Example

| invoice_number | cr_issue | combined_key |
|---|---|---|
| IN#5767636 | CR#515461 | IN#5767636CR#515461 |

### Better readable version

```sql
SELECT
    CONCAT(invoice_number, ' | ', cr_issue) AS combined_key
FROM dbo.step_02_po_details;
```

Output:

```text
IN#5767636 | CR#515461
```

---

# Blank Dynamic Columns

---

## Query 19: Create one blank invoice column

```sql
SELECT
    ref,
    CAST(NULL AS varchar(50)) AS [Feb-26]
FROM dbo.step_01a_cr_sheet;
```

### What it does

Creates a blank column called `[Feb-26]`.

### Example output

| ref | Feb-26 |
|---|---|
| CR#515461 | NULL |
| CR#515630 | NULL |

### Why use this

In Credit Applied Sheet, some rows need blank invoice/month columns.

---

## Query 20: Generate blank columns dynamically

```sql
SELECT STRING_AGG(
    'CAST(NULL AS varchar(50)) AS ' + QUOTENAME(ref),
    ','
)
FROM dbo.step_01a_in_sheet;
```

### What it does

Creates dynamic blank columns for every invoice.

### Example output

```sql
CAST(NULL AS varchar(50)) AS [IN#5767636],
CAST(NULL AS varchar(50)) AS [IN#5777129]
```

### Use case

This is used in dynamic SQL like:

```sql
SELECT
    ref AS [Credit #],
    CAST(NULL AS varchar(50)) AS [IN#5767636],
    CAST(NULL AS varchar(50)) AS [IN#5777129],
    ABS(TRY_CAST(pay_day AS decimal(18,2))) AS [Credit Amount]
FROM dbo.step_01a_cr_sheet;
```

---

# Dynamic SUM CASE Generator

---

## Query 21: Generate SUM CASE columns dynamically

```sql
SELECT STRING_AGG(
    'SUM(
        CASE
            WHEN invoice_number = '''
            + ref +
            ''' THEN qxc ELSE 0 END
     ) AS ' + QUOTENAME(ref),
    ','
)
FROM dbo.step_01a_in_sheet;
```

### What it does

Generates this type of SQL automatically:

```sql
SUM(CASE WHEN invoice_number = 'IN#5767636' THEN qxc ELSE 0 END) AS [IN#5767636],
SUM(CASE WHEN invoice_number = 'IN#5777129' THEN qxc ELSE 0 END) AS [IN#5777129]
```

### Important safer version

Use `REPLACE` and `TRY_CAST`:

```sql
SELECT STRING_AGG(
    'SUM(
        CASE
            WHEN LTRIM(RTRIM(invoice_number)) = '''
            + REPLACE(ref,'''','''''') +
            ''' THEN ISNULL(TRY_CAST(qxc AS decimal(18,2)),0)
            ELSE 0
        END
     ) AS ' + QUOTENAME(ref),
    ','
)
FROM dbo.step_01a_in_sheet;
```

### Why this is important

This is the main building block for dynamic pivot-style output.

---

# Final Combined Example: Dynamic Invoice Totals

This query dynamically creates one column for each invoice and sums `qxc`.

```sql
DECLARE @sum_cols NVARCHAR(MAX);
DECLARE @sql NVARCHAR(MAX);

SELECT @sum_cols =
STRING_AGG(
    'SUM(
        CASE
            WHEN LTRIM(RTRIM(invoice_number)) = '''
            + REPLACE(ref,'''','''''') +
            ''' THEN ISNULL(TRY_CAST(qxc AS decimal(18,2)),0)
            ELSE 0
        END
    ) AS ' + QUOTENAME(ref),
    ','
)
FROM dbo.step_01a_in_sheet;

SET @sql = '
SELECT
    ' + @sum_cols + '
FROM dbo.step_02_po_details;
';

PRINT @sql;
EXEC sp_executesql @sql;
```

## Example output

| IN#5767636 | IN#5777129 |
|---:|---:|
| 150.00 | 200.00 |

---

# Final Combined Example: Credit Rows with Blank Invoice Columns

```sql
DECLARE @blank_cols NVARCHAR(MAX);
DECLARE @sql NVARCHAR(MAX);

SELECT @blank_cols =
STRING_AGG(
    'CAST(NULL AS varchar(50)) AS ' + QUOTENAME(ref),
    ','
)
FROM dbo.step_01a_in_sheet;

SET @sql = '
SELECT
    ref AS [Credit #],
    ' + @blank_cols + ',
    ABS(TRY_CAST(pay_day AS decimal(18,2))) AS [Credit Amount]
FROM dbo.step_01a_cr_sheet;
';

PRINT @sql;
EXEC sp_executesql @sql;
```

## Example output

| Credit # | IN#5767636 | IN#5777129 | Credit Amount |
|---|---|---|---:|
| CR#515461 | NULL | NULL | 150.00 |
| CR#515630 | NULL | NULL | 200.00 |

---

# Beginner Summary

## What you learned

| Concept | Meaning |
|---|---|
| `STRING_AGG` | Combine many rows into one text |
| `QUOTENAME` | Make safe SQL column name |
| `DECLARE` | Create variable |
| `PRINT` | Show variable value |
| `CASE` | If/else logic in SQL |
| `SUM(CASE...)` | Conditional total |
| `GROUP BY` | Total by category |
| `TRY_CAST` | Convert safely |
| `ISNULL` | Replace NULL |
| `LEFT JOIN` | Keep all left table rows |
| `FULL OUTER JOIN` | Keep all rows from both tables |
| `CONCAT` | Join text |
| `LTRIM/RTRIM` | Remove spaces |
| `ABS` | Make number positive |
| `EXEC sp_executesql` | Run dynamic SQL text |

---

# Core Formula for Dynamic Pivot

Manual logic:

```sql
SUM(CASE WHEN invoice_number = 'IN#5767636' THEN qxc ELSE 0 END) AS [IN#5767636]
```

Dynamic generator:

```sql
STRING_AGG(
    'SUM(CASE WHEN invoice_number = '''
    + ref +
    ''' THEN qxc ELSE 0 END) AS ' + QUOTENAME(ref),
    ','
)
```

Final idea:

> First generate SQL text, then execute it.

```sql
PRINT @sql;
EXEC sp_executesql @sql;
```

---

# Recommended Practice Order

1. Practice `STRING_AGG`
2. Practice `QUOTENAME`
3. Practice `CASE`
4. Practice `SUM(CASE...)`
5. Practice `GROUP BY`
6. Practice `TRY_CAST`
7. Practice `JOIN`
8. Generate dynamic columns
9. Generate dynamic `SUM(CASE...)`
10. Build final dynamic SQL

---

# Notes

Always print dynamic SQL before running:

```sql
PRINT @sql;
```

This helps you debug the real query SQL Server is going to execute.

