/*
 * ----------------------------------------------------------------------------
 * 03_core_views.sql
 *
 * Creates the primary analytical views for calculating academic stats.
 * - v_student_academic_summary: The main engine for transcripts,
 * calculating running semester and cumulative GPAs using window functions.
 * - v_student_overall_summary: High-level summary for each student.
 * - v_department_performance: Department-level GPA analytics.
 * ----------------------------------------------------------------------------
 */

-- 1. View: Student Academic Summary (Transcript Engine)
-- This is the main view for generating transcripts.
-- It uses window functions to calculate semester and cumulative (running)
-- GPAs for every course a student has taken.
CREATE OR REPLACE VIEW v_student_academic_summary AS
WITH semester_stats AS (
    -- First, calculate total quality points and GPA-applicable credits
    -- for each *semester* for each student.
    SELECT
        id,
        semester,
        year,
        SUM(quality_points) AS semester_quality_points,
        SUM(CASE WHEN is_gpa_applicable THEN credits ELSE 0 END) AS semester_gpa_credits
    FROM
        v_student_grade_points
    GROUP BY
        id, semester, year
),
cumulative_stats AS (
    -- Next, use window functions to calculate cumulative (running)
    -- stats based on the per-semester stats.
    SELECT
        id,
        semester,
        year,
        semester_quality_points,
        semester_gpa_credits,
        -- Calculate semester GPA, avoiding division by zero
        (semester_quality_points / NULLIF(semester_gpa_credits, 0)) AS semester_gpa,
        -- Calculate cumulative (running) quality points
        SUM(semester_quality_points) OVER (
            PARTITION BY id ORDER BY year, semester
        ) AS cumulative_quality_points,
        -- Calculate cumulative (running) GPA-applicable credits
        SUM(semester_gpa_credits) OVER (
            PARTITION BY id ORDER BY year, semester
        ) AS cumulative_gpa_credits
    FROM
        semester_stats
)
-- Finally, join the per-course data (from v_student_grade_points)
-- with the per-semester and cumulative stats.
SELECT
    sgp.id,
    sgp.semester,
    sgp.year,
    (sgp.semester || ' ' || sgp.year::TEXT) AS term,
    sgp.course_id,
    sgp.title,
    sgp.credits,
    sgp.grade,
    cs.semester_gpa,
    -- Calculate final cumulative GPA, avoiding division by zero
    (cs.cumulative_quality_points / NULLIF(cs.cumulative_gpa_credits, 0)) AS cumulative_gpa
FROM
    v_student_grade_points sgp
JOIN
    cumulative_stats cs ON sgp.id = cs.id
    AND sgp.semester = cs.semester
    AND sgp.year = cs.year;


-- 2. View: Student Overall Summary
-- Provides a single-row summary for each student, including their
-- overall GPA and total *earned* credits (i.e., from passed courses).
CREATE OR REPLACE VIEW v_student_overall_summary AS
SELECT
    s.id AS student_id,
    s.name,
    s.dept_name,
    -- Calculate total credits earned (passed courses)
    SUM(CASE WHEN sgp.is_passed THEN sgp.credits ELSE 0 END) AS total_credits_earned,
    -- Calculate overall cumulative GPA
    (
        SUM(sgp.quality_points) /
        NULLIF(SUM(CASE WHEN sgp.is_gpa_applicable THEN sgp.credits ELSE 0 END), 0)
    ) AS cumulative_gpa
FROM
    student s
LEFT JOIN
    v_student_grade_points sgp ON s.id = sgp.id
GROUP BY
    s.id, s.name, s.dept_name;


-- 3. View: Department Performance
-- Calculates the true credit-weighted average GPA for each department.
-- This avoids the "average of averages" problem by summing all
-- quality points and dividing by all GPA credits in each department.
CREATE OR REPLACE VIEW v_department_performance AS
SELECT
    d.dept_name,
    COUNT(DISTINCT s.id) AS num_students,
    (
        SUM(sgp.quality_points) /
        NULLIF(SUM(CASE WHEN sgp.is_gpa_applicable THEN sgp.credits ELSE 0 END), 0)
    ) AS department_avg_gpa
FROM
    department d
LEFT JOIN
    student s ON d.dept_name = s.dept_name
LEFT JOIN
    v_student_grade_points sgp ON s.id = sgp.id
GROUP BY
    d.dept_name;
