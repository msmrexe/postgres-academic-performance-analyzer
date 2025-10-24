/*
 * ----------------------------------------------------------------------------
 * 04_transcript_functions.sql
 *
 * Defines the main PL/pgSQL functions for generating reports.
 * - udf_generate_transcript: Returns a full academic transcript for a student.
 * - udf_get_deans_list: Returns students who meet a GPA threshold
 * for a given semester.
 * ----------------------------------------------------------------------------
 */

-- 1. Function: Generate Transcript
-- This function returns a complete transcript for a given student ID.
-- It queries the main v_student_academic_summary view.
CREATE OR REPLACE FUNCTION udf_generate_transcript(p_student_id student.id%TYPE)
RETURNS TABLE (
    term TEXT,
    course_id VARCHAR(8),
    title VARCHAR(50),
    credits NUMERIC(2, 0),
    grade VARCHAR(2),
    semester_gpa NUMERIC,
    cumulative_gpa NUMERIC
)
LANGUAGE sql
STABLE
AS $$
    SELECT
        sas.term,
        sas.course_id,
        sas.title,
        sas.credits,
        sas.grade,
        -- Round GPAs to 2 decimal places for a clean transcript
        ROUND(sas.semester_gpa, 2) AS semester_gpa,
        ROUND(sas.cumulative_gpa, 2) AS cumulative_gpa
    FROM
        v_student_academic_summary sas
    WHERE
        sas.id = p_student_id
    ORDER BY
        sas.year, sas.semester, sas.course_id;
$$;


-- 2. Function: Get Dean's List
-- Returns all students who achieved a certain GPA in a given semester.
CREATE OR REPLACE FUNCTION udf_get_deans_list(
    p_semester section.semester%TYPE,
    p_year section.year%TYPE,
    p_min_gpa NUMERIC
)
RETURNS TABLE (
    student_id VARCHAR(5),
    name VARCHAR(20),
    dept_name VARCHAR(20),
    semester_gpa NUMERIC
)
LANGUAGE sql
STABLE
AS $$
    -- We need one row per student per semester.
    -- We can get this by using DISTINCT ON from the main summary view.
    WITH semester_gp_stats AS (
        SELECT DISTINCT ON (id, semester, year)
            id,
            semester,
            year,
            semester_gpa
        FROM
            v_student_academic_summary
    )
    SELECT
        s.id,
        s.name,
        s.dept_name,
        ROUND(sgs.semester_gpa, 2) AS semester_gpa
    FROM
        semester_gp_stats sgs
    JOIN
        student s ON sgs.id = s.id
    WHERE
        sgs.semester = p_semester
        AND sgs.year = p_year
        AND sgs.semester_gpa >= p_min_gpa
    ORDER BY
        sgs.semester_gpa DESC, s.name;
$$;
