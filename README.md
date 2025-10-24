# Academic Transcript Generator & Analyzer (PostgreSQL)

This project simulates a smart university academic analyzer within a PostgreSQL database. It uses advanced PL/pgSQL functions, views, and window functions to generate detailed student transcripts, calculate semester and cumulative GPAs, and provide analytical views based on academic performance.

This project was developed from a series of "Mathematical Databases" course homework assignments to create a single, cohesive, and self-contained application.

## Features

* **Accurate Grade Point Conversion:** A standardized function converts letter grades (e.g., 'A', 'B+', 'C-') to a standard numerical 4.0 scale (e.g., 4.0, 3.3, 1.7), correctly handling non-GPA-applicable grades.
* **Transcript Generation Function:** A `udf_generate_transcript(student_id)` function returns a complete academic history for a student, grouped by term, showing all courses, credits, grades, semester GPA, and a *running* cumulative GPA.
* **Credit-Weighted GPA Logic:** All GPA calculations are correctly weighted by course credits and properly handle `NULL` or non-standard grades.
* **Student Summary View:** A `v_student_overall_summary` view provides a high-level look at each student's total *earned* credits and final cumulative GPA.
* **Department Performance View:** A `v_department_performance` view calculates the true, credit-weighted average GPA for all students in each department.
* **Dean's List Function:** A `udf_get_deans_list(semester, year, min_gpa)` function returns students who meet a specific GPA threshold for a given term.

## Database Concepts Showcased

* **Advanced SQL:** Extensive use of multi-table joins, aggregations (`SUM`, `AVG`, `COUNT`), and complex `CASE` statements.
* **Window Functions:** The core of the project. Used to calculate running totals for cumulative GPA (`SUM(...) OVER (PARTITION BY ... ORDER BY ...)`).
* **PL/pgSQL:** Writing table-returning functions (`RETURNS TABLE`) to create a clean, parameterized API for reports.
* **Database Views:** Creating a layered system of views (`v_student_grade_points` -> `v_student_academic_summary` -> `v_student_overall_summary`) to abstract complexity and promote reusability.
* **Data Transformation:** Converting data from one format to another (letter grades to numeric points) and aggregating transactional data (`takes`) into meaningful reports.
* **Reporting & Analytics:** Generating meaningful summaries (transcripts, departmental performance) from raw data.

---

## How It Works

The system is built on two pillars: the database schema (the tables) and the business logic (the functions and views).

### 1. Database Schema Overview

This project builds on the existing university schema. The logic primarily revolves around these key tables:

* **`student`**: Stores student information (ID, name, department).
* **`course`**: Stores course definitions, including `course_id`, `title`, and `credits`.
* **`takes`**: The central transaction table. An entry here signifies that a `student` has taken a `section`. It stores the `grade`.
* **`department`**: Used for grouping students to calculate departmental performance.

### 2. Core Logic and Functions

The logic is implemented in a series of layered views and functions.

#### Helper Views and Functions (`src/02_grade_helpers.sql`)

* **`udf_convert_grade_to_points(grade)`**: A simple, immutable function that converts a letter grade `VARCHAR` into a `NUMERIC` grade point. This is the single source of truth for all grade conversions.
* **`v_student_grade_points`**: This is the foundational view. It joins `takes` and `course` and, for every row, calculates the `grade_points` (from the function above) and the `quality_points` (which is `grade_points * credits`). It also includes boolean flags `is_gpa_applicable` and `is_passed` for precise calculations.

#### Core Analytical Views (`src/03_core_views.sql`)

* **`v_student_academic_summary`**: This is the main engine for the transcript. It first calculates per-semester stats (total quality points and GPA-applicable credits). Then, it uses window functions to calculate the *running cumulative* quality points and credits. Finally, it joins this data back to the per-course view (`v_student_grade_points`) to create a complete row-by-row academic history, annotated with the correct `semester_gpa` and `cumulative_gpa` for that term.
* **`v_student_overall_summary`**: This view provides a simple, one-row-per-student summary. It calculates the *final* `cumulative_gpa` and the `total_credits_earned` (based on `is_passed = true`).
* **`v_department_performance`**: This view calculates a true, credit-weighted average GPA for each department by aggregating the `quality_points` and `credits` from *all* students in that department.

#### Main Functions (`src/04_transcript_functions.sql`)

* **`udf_generate_transcript(student_id)`**: This is a simple SQL function that acts as a clean API. It just `SELECT`s all relevant columns from the `v_student_academic_summary` view for a specific student, providing a ready-to-use transcript.
* **`udf_get_deans_list(semester, year, min_gpa)`**: This function uses `DISTINCT ON (id, semester, year)` on the main summary view to get a single, definitive GPA for each student for each term, then filters them by the function parameters.

---

## Project Structure

```
postgres-academic-performance-analyzer/
├── .gitignore                        # Ignores system and credential files
├── LICENSE                           # MIT license file
├── README.md                         # This documentation
├── demo.sql                          # Example script showing how to use the system
└── src/
    ├── 00_schema.sql                 # Main DDL script to create all tables
    ├── 01_data.sql                   # Script to insert sample data
    ├── 02_grade_helpers.sql          # Creates grade conversion function and base view
    ├── 03_core_views.sql             # Creates the main analytical/summary views
    └── 04_transcript_functions.sql   # Creates the final report functions
```

## How to Use

1.  **Setup Database:**
    Create a new PostgreSQL database.
    ```bash
    createdb university_db
    ```

2.  **Connect to Database:**
    Use `psql` or any SQL client to connect to your new database.
    ```bash
    psql university_db
    ```

3.  **Run SQL Scripts (in order):**
    Execute the SQL scripts from the `src/` directory in numerical order.

    ```sql
    -- 1. Create the schema
    \i src/00_schema.sql
    
    -- 2. Load the sample data
    \i src/01_data.sql
    
    -- 3. Create helper views and functions
    \i src/02_grade_helpers.sql
    
    -- 4. Create the main analytical views
    \i src/03_core_views.sql
    
    -- 5. Create the final report functions
    \i src/04_transcript_functions.sql
    ```

4.  **Test the System:**
    Run the `demo.sql` script to see the system in action. This script is wrapped in a `BEGIN...ROLLBACK` block, so it will not make permanent changes to your data.

    ```sql
    \i demo.sql
    ```
    You will see output for each test case, for example:
    ```
     student_id |  name   |  dept_name  | total_credits_earned |   cumulative_gpa
    ------------+---------+-------------+----------------------+----------------------
     00128      | Zhang   | Comp. Sci.  |                    7 | 3.8571428571428571
     12345      | Shankar | Comp. Sci.  |                   14 | 3.5000000000000000
     45678      | Levy    | Physics     |                    7 | 2.5454545454545455
    (3 rows)
    ```

## Example Function Call

You can call the functions directly at any time:

```sql
-- Generate a transcript for a specific student
SELECT * FROM udf_generate_transcript('12345');

-- Find students for the Dean's List
SELECT * FROM udf_get_deans_list('Fall', 2017, 3.75);
```

---

## Author

Feel free to connect or reach out if you have any questions!

* **Maryam Rezaee**
* **GitHub:** [@msmrexe](https://github.com/msmrexe)
* **Email:** [ms.maryamrezaee@gmail.com](mailto:ms.maryamrezaee@gmail.com)

---

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for full details.
