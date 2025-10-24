/*
 * ----------------------------------------------------------------------------
 * 02_grade_helpers.sql
 *
 * Defines the foundational function for converting letter grades to
 * numeric points and a base view that calculates quality points
 * for all 'takes' records.
 * ----------------------------------------------------------------------------
 */

-- 1. Helper Function: Convert Grade to Numeric Points
-- Defines the standard mapping from letter grades to a 4.0 scale.
-- Returns NULL for non-standard grades (like 'W' or NULL).
CREATE OR REPLACE FUNCTION udf_convert_grade_to_points(p_grade VARCHAR(2))
RETURNS NUMERIC(2, 1)
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
    RETURN CASE
        WHEN p_grade = 'A'  THEN 4.0
        WHEN p_grade = 'A-' THEN 3.7
        WHEN p_grade = 'B+' THEN 3.3
        WHEN p_grade = 'B'  THEN 3.0
        WHEN p_grade = 'B-' THEN 2.7
        WHEN p_grade = 'C+' THEN 2.3
        WHEN p_grade = 'C'  THEN 2.0
        WHEN p_grade = 'C-' THEN 1.7
        WHEN p_grade = 'D+' THEN 1.3
        WHEN p_grade = 'D'  THEN 1.0
        WHEN p_grade = 'D-' THEN 0.7
        WHEN p_grade = 'F'  THEN 0.0
        ELSE NULL -- For NULL, 'W', 'P', etc.
    END;
END;
$$;

-- 2. Base View: Student Grade Points
-- This view is the foundation for all GPA calculations.
-- It joins 'takes' with 'course' to get credits and calculates
-- the grade points and total quality points (credits * grade_points)
-- for every course a student has taken.
CREATE OR REPLACE VIEW v_student_grade_points AS
SELECT
    t.id,
    t.course_id,
    c.title,
    t.sec_id,
    t.semester,
    t.year,
    t.grade,
    c.credits,
    udf_convert_grade_to_points(t.grade) AS grade_points,
    -- Quality Points are the basis for credit-weighted GPA
    (c.credits * udf_convert_grade_to_points(t.grade)) AS quality_points,
    -- Flag for whether this course counts towards GPA
    (udf_convert_grade_to_points(t.grade) IS NOT NULL) AS is_gpa_applicable,
    -- Flag for whether this course was passed (for earned credits)
    (udf_convert_grade_to_points(t.grade) > 0.0) AS is_passed
FROM
    takes t
JOIN
    course c ON t.course_id = c.course_id;
