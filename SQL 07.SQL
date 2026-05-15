/*==============================================================
 STEP 07 FINAL - FULL QUERY

 Layout:
 Credit #
 Blank_1
 Dynamic Invoice Columns
 Blank_2
 Credit Amount Applied
 Blank_3
 Credit Amount As Per A/R Report
 Blank_4
 Difference

 Extra rows:
 Total Credit Amount
 YCS Invoice+DB Amount
 Difference
 Unpaid
 Net Difference
==============================================================*/

DROP TABLE IF EXISTS dbo.step_07_final;
GO

DECLARE 
    @header_cols        NVARCHAR(MAX),
    @month_cols         NVARCHAR(MAX),
    @cr_inv_cols        NVARCHAR(MAX),
    @cr_total_formula   NVARCHAR(MAX),
    @ycs_cols           NVARCHAR(MAX),
    @ycs_total_formula  NVARCHAR(MAX),
    @diff_cols          NVARCHAR(MAX),
    @diff_total_formula NVARCHAR(MAX),
    @unpaid_cols        NVARCHAR(MAX),
    @unpaid_total       NVARCHAR(MAX),
    @net_diff_cols      NVARCHAR(MAX),
    @net_diff_total     NVARCHAR(MAX),
    @sql                NVARCHAR(MAX);

/* HEADER INVOICE COLUMNS */
SELECT @header_cols =
STRING_AGG(
    '''' + REPLACE(ref,'''','''''') + ''' AS ' + QUOTENAME(ref),
    ','
)
FROM dbo.step_01a_in_sheet;

/* MONTH ROW */
SELECT @month_cols =
STRING_AGG(
    '''' + FORMAT(TRY_CONVERT(date, Ndatee), 'MMM-yy') + ''' AS ' + QUOTENAME(ref),
    ','
)
FROM dbo.step_01a_in_sheet;

/* CR DATA INVOICE VALUES */
SELECT @cr_inv_cols =
STRING_AGG(
'
CAST
(
    SUM
    (
        CASE
            WHEN LTRIM(RTRIM(p.invoice_number)) = '''
            + REPLACE(ref,'''','''''') +
            '''
            THEN ISNULL(TRY_CAST(p.qxc AS decimal(18,2)),0)
            ELSE 0
        END
    )
AS varchar(50)) AS ' + QUOTENAME(ref),
','
)
FROM dbo.step_01a_in_sheet;

/* CREDIT AMOUNT APPLIED */
SELECT @cr_total_formula =
STRING_AGG(
'
SUM
(
    CASE
        WHEN LTRIM(RTRIM(p.invoice_number)) = '''
        + REPLACE(ref,'''','''''') +
        '''
        THEN ISNULL(TRY_CAST(p.qxc AS decimal(18,2)),0)
        ELSE 0
    END
)
',
'+'
)
FROM dbo.step_01a_in_sheet;

/* YCS ROW */
SELECT @ycs_cols =
STRING_AGG(
'
CAST
(
    SUM
    (
        CASE
            WHEN LTRIM(RTRIM(p.invoice_number)) = '''
            + REPLACE(ref,'''','''''') +
            '''
            THEN ISNULL(TRY_CAST(p.qxc AS decimal(18,2)),0)
            ELSE 0
        END
    )
AS varchar(50)) AS ' + QUOTENAME(ref),
','
)
FROM dbo.step_01a_in_sheet;

SELECT @ycs_total_formula =
STRING_AGG(
'
SUM
(
    CASE
        WHEN LTRIM(RTRIM(p.invoice_number)) = '''
        + REPLACE(ref,'''','''''') +
        '''
        THEN ISNULL(TRY_CAST(p.qxc AS decimal(18,2)),0)
        ELSE 0
    END
)
',
'+'
)
FROM dbo.step_01a_in_sheet;

/* DIFFERENCE ROW = YCS - TOTAL CREDIT */
SELECT @diff_cols =
STRING_AGG(
'
CAST
(
    ISNULL((
        SELECT SUM(TRY_CAST(p1.qxc AS decimal(18,2)))
        FROM dbo.step_02_po_details p1
        WHERE LTRIM(RTRIM(p1.invoice_number)) = '''
        + REPLACE(ref,'''','''''') +
        '''
    ),0)
    -
    ISNULL((
        SELECT SUM(TRY_CAST(p2.qxc AS decimal(18,2)))
        FROM dbo.step_01a_cr_sheet c2
        LEFT JOIN dbo.step_02_po_details p2
            ON LTRIM(RTRIM(p2.cr_issue)) = LTRIM(RTRIM(c2.ref))
        WHERE LTRIM(RTRIM(p2.invoice_number)) = '''
        + REPLACE(ref,'''','''''') +
        '''
    ),0)
AS varchar(50)) AS ' + QUOTENAME(ref),
','
)
FROM dbo.step_01a_in_sheet;

SELECT @diff_total_formula =
STRING_AGG(
'
ISNULL((
    SELECT SUM(TRY_CAST(p1.qxc AS decimal(18,2)))
    FROM dbo.step_02_po_details p1
    WHERE LTRIM(RTRIM(p1.invoice_number)) = '''
    + REPLACE(ref,'''','''''') +
    '''
),0)
-
ISNULL((
    SELECT SUM(TRY_CAST(p2.qxc AS decimal(18,2)))
    FROM dbo.step_01a_cr_sheet c2
    LEFT JOIN dbo.step_02_po_details p2
        ON LTRIM(RTRIM(p2.cr_issue)) = LTRIM(RTRIM(c2.ref))
    WHERE LTRIM(RTRIM(p2.invoice_number)) = '''
    + REPLACE(ref,'''','''''') +
    '''
),0)
',
'+'
)
FROM dbo.step_01a_in_sheet;

/* UNPAID ROW */
SELECT @unpaid_cols =
STRING_AGG(
'
CAST
(
    ISNULL((
        SELECT TOP 1
            TRY_CAST(m.sumByInv_unpaid AS decimal(18,2))
        FROM dbo.step_04b_order_not_matched m
        WHERE LTRIM(RTRIM(m.invoice_number)) = '''
        + REPLACE(ref,'''','''''') +
        '''
    ),0)
AS varchar(50)) AS ' + QUOTENAME(ref),
','
)
FROM dbo.step_01a_in_sheet;

SELECT @unpaid_total =
STRING_AGG(
'
ISNULL((
    SELECT TOP 1
        TRY_CAST(m.sumByInv_unpaid AS decimal(18,2))
    FROM dbo.step_04b_order_not_matched m
    WHERE LTRIM(RTRIM(m.invoice_number)) = '''
    + REPLACE(ref,'''','''''') +
    '''
),0)
',
'+'
)
FROM dbo.step_01a_in_sheet;

/* NET DIFFERENCE = DIFFERENCE - UNPAID */
SELECT @net_diff_cols =
STRING_AGG(
'
CAST
(
    (
        ISNULL((
            SELECT SUM(TRY_CAST(p1.qxc AS decimal(18,2)))
            FROM dbo.step_02_po_details p1
            WHERE LTRIM(RTRIM(p1.invoice_number)) = '''
            + REPLACE(ref,'''','''''') +
            '''
        ),0)
        -
        ISNULL((
            SELECT SUM(TRY_CAST(p2.qxc AS decimal(18,2)))
            FROM dbo.step_01a_cr_sheet c2
            LEFT JOIN dbo.step_02_po_details p2
                ON LTRIM(RTRIM(p2.cr_issue)) = LTRIM(RTRIM(c2.ref))
            WHERE LTRIM(RTRIM(p2.invoice_number)) = '''
            + REPLACE(ref,'''','''''') +
            '''
        ),0)
        -
        ISNULL((
            SELECT TOP 1
                TRY_CAST(m.sumByInv_unpaid AS decimal(18,2))
            FROM dbo.step_04b_order_not_matched m
            WHERE LTRIM(RTRIM(m.invoice_number)) = '''
            + REPLACE(ref,'''','''''') +
            '''
        ),0)
    )
AS varchar(50)) AS ' + QUOTENAME(ref),
','
)
FROM dbo.step_01a_in_sheet;

SELECT @net_diff_total =
STRING_AGG(
'
(
    ISNULL((
        SELECT SUM(TRY_CAST(p1.qxc AS decimal(18,2)))
        FROM dbo.step_02_po_details p1
        WHERE LTRIM(RTRIM(p1.invoice_number)) = '''
        + REPLACE(ref,'''','''''') +
        '''
    ),0)
    -
    ISNULL((
        SELECT SUM(TRY_CAST(p2.qxc AS decimal(18,2)))
        FROM dbo.step_01a_cr_sheet c2
        LEFT JOIN dbo.step_02_po_details p2
            ON LTRIM(RTRIM(p2.cr_issue)) = LTRIM(RTRIM(c2.ref))
        WHERE LTRIM(RTRIM(p2.invoice_number)) = '''
        + REPLACE(ref,'''','''''') +
        '''
    ),0)
    -
    ISNULL((
        SELECT TOP 1
            TRY_CAST(m.sumByInv_unpaid AS decimal(18,2))
        FROM dbo.step_04b_order_not_matched m
        WHERE LTRIM(RTRIM(m.invoice_number)) = '''
        + REPLACE(ref,'''','''''') +
        '''
    ),0)
)
',
'+'
)
FROM dbo.step_01a_in_sheet;

/* FINAL REPORT */
SET @sql = '
SELECT *
INTO dbo.step_07_final
FROM
(
    SELECT
        ''Credit #'' AS [Credit #],
        NULL AS [Blank_1],
        ' + @header_cols + ',
        NULL AS [Blank_2],
        ''Credit Amount Applied'' AS [Credit Amount Applied],
        NULL AS [Blank_3],
        ''Credit Amount As Per A/R Report'' AS [Credit Amount As Per A/R Report],
        NULL AS [Blank_4],
        ''Difference'' AS [Difference]

    UNION ALL

    SELECT
        ''Invoice Month'' AS [Credit #],
        NULL AS [Blank_1],
        ' + @month_cols + ',
        NULL AS [Blank_2],
        NULL AS [Credit Amount Applied],
        NULL AS [Blank_3],
        NULL AS [Credit Amount As Per A/R Report],
        NULL AS [Blank_4],
        NULL AS [Difference]

    UNION ALL

    SELECT
        c.ref AS [Credit #],
        NULL AS [Blank_1],
        ' + @cr_inv_cols + ',
        NULL AS [Blank_2],
        CAST((' + @cr_total_formula + ') AS varchar(50)) AS [Credit Amount Applied],
        NULL AS [Blank_3],
        CAST(ABS(ISNULL(TRY_CAST(c.pay_day AS decimal(18,2)),0)) AS varchar(50)) AS [Credit Amount As Per A/R Report],
        NULL AS [Blank_4],
        CAST(
            ABS(ISNULL(TRY_CAST(c.pay_day AS decimal(18,2)),0))
            -
            (' + @cr_total_formula + ')
        AS varchar(50)) AS [Difference]

    FROM dbo.step_01a_cr_sheet c
    LEFT JOIN dbo.step_02_po_details p
        ON LTRIM(RTRIM(p.cr_issue)) = LTRIM(RTRIM(c.ref))
    GROUP BY c.ref, c.pay_day

    UNION ALL

    SELECT
        ''Total Credit Amount'' AS [Credit #],
        NULL AS [Blank_1],
        ' + @cr_inv_cols + ',
        NULL AS [Blank_2],
        CAST((' + @cr_total_formula + ') AS varchar(50)) AS [Credit Amount Applied],
        NULL AS [Blank_3],
        CAST((
            SELECT SUM(ABS(ISNULL(TRY_CAST(c3.pay_day AS decimal(18,2)),0)))
            FROM dbo.step_01a_cr_sheet c3
        ) AS varchar(50)) AS [Credit Amount As Per A/R Report],
        NULL AS [Blank_4],
        CAST(
            (
                SELECT SUM(ABS(ISNULL(TRY_CAST(c3.pay_day AS decimal(18,2)),0)))
                FROM dbo.step_01a_cr_sheet c3
            )
            -
            (' + @cr_total_formula + ')
        AS varchar(50)) AS [Difference]

    FROM dbo.step_01a_cr_sheet c
    LEFT JOIN dbo.step_02_po_details p
        ON LTRIM(RTRIM(p.cr_issue)) = LTRIM(RTRIM(c.ref))

    UNION ALL

    SELECT
        ''YCS Invoice+DB Amount'' AS [Credit #],
        NULL AS [Blank_1],
        ' + @ycs_cols + ',
        NULL AS [Blank_2],
        CAST((' + @ycs_total_formula + ') AS varchar(50)) AS [Credit Amount Applied],
        NULL AS [Blank_3],
        NULL AS [Credit Amount As Per A/R Report],
        NULL AS [Blank_4],
        NULL AS [Difference]

    FROM dbo.step_02_po_details p

    UNION ALL

    SELECT
        ''Difference'' AS [Credit #],
        NULL AS [Blank_1],
        ' + @diff_cols + ',
        NULL AS [Blank_2],
        CAST((' + @diff_total_formula + ') AS varchar(50)) AS [Credit Amount Applied],
        NULL AS [Blank_3],
        NULL AS [Credit Amount As Per A/R Report],
        NULL AS [Blank_4],
        NULL AS [Difference]

    UNION ALL

    SELECT
        ''Unpaid'' AS [Credit #],
        NULL AS [Blank_1],
        ' + @unpaid_cols + ',
        NULL AS [Blank_2],
        CAST((' + @unpaid_total + ') AS varchar(50)) AS [Credit Amount Applied],
        NULL AS [Blank_3],
        NULL AS [Credit Amount As Per A/R Report],
        NULL AS [Blank_4],
        NULL AS [Difference]

    UNION ALL

    SELECT
        ''Net Difference'' AS [Credit #],
        NULL AS [Blank_1],
        ' + @net_diff_cols + ',
        NULL AS [Blank_2],
        CAST((' + @net_diff_total + ') AS varchar(50)) AS [Credit Amount Applied],
        NULL AS [Blank_3],
        NULL AS [Credit Amount As Per A/R Report],
        NULL AS [Blank_4],
        NULL AS [Difference]

) x;
';

PRINT @sql;
EXEC sp_executesql @sql;
GO

SELECT *
FROM dbo.step_07_final;
GO
