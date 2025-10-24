/*
 * ----------------------------------------------------------------------------
 * demo.sql
 *
 * This script demonstrates the functionality of the Academic Analyzer.
 * Run this after loading the schema, data, and all 'src' files.
 *
 * Note: This demo is wrapped in a transaction, which is rolled back
 * at the end, so no changes are saved.
 * ----------------------------------------------------------------------------
 */

BEGIN;

-- 1. Show a high-level summary for a few students
SELECT * FROM v_student_overall_summary
WHERE student_id IN ('00128', '12345', '45678');
-- Note: '45678' (Levy) failed CS-101 (0 credits earned), then passed
-- (4 credits earned). Total earned should be 4 + 3 = 7 (from CS-319),
-- not 4 + 4 + 3. Our view correctly calculates total *earned* credits.

-- 2. Show the overall department performance
SELECT * FROM v_department_performance
ORDER BY department_avg_gpa DESC;

-- 3. Find the "Dean's List" for Fall 2017 with a 3.5+ GPA
SELECT * FROM udf_get_deans_list('Fall', 2017, 3.5);

-- 4. Find the "Dean's List" for Spring 2018 with a 3.0+ GPA
SELECT * FROM udf_get_deans_list('Spring', 2018, 3.0);

-- 5. Generate a full transcript for student '00128' (Zhang)
-- This student took two courses in one semester (Fall 2017).
SELECT * FROM udf_generate_transcript('00128');
-- Note how Semester/Cumulative GPA are the same for both rows in Fall 2017.

-- 6. Generate a full transcript for student '45678' (Levy)
-- This student failed and retook a course.
SELECT * FROM udf_generate_transcript('45678');
-- Note how the cumulative_gpa drops in Fall 2017 (due to 'F')
-- and then recovers in Spring 2018 (with 'B+' and 'B').

ROLLBACK;
