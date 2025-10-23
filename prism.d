/*
    This file is part of the Prism distribution.

    https://github.com/SenseLogic/PRISM

    Copyright (C) 2025 Eric Pelzer (ecstatic.coder@gmail.com)

    Prism is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, version 3.

    Prism is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Prism.  If not, see <http://www.gnu.org/licenses/>.
*/

// -- IMPORTS

import core.stdc.stdlib : exit;
import std.algorithm : countUntil, sort;
import std.conv : to;
import std.datetime;
import std.file : dirEntries, exists, isFile, mkdirRecurse, readText, write, SpanMode;
import std.path : absolutePath;
import std.regex : matchFirst, regex, Regex;
import std.stdio : writeln;
import std.string : endsWith, indexOf, join, lastIndexOf, replace, split, startsWith, strip, stripLeft, stripRight;

// -- TYPES

class TASK
{
    // -- ATTRIBUTES

    DEVELOPER
        Developer;
    PROJECT
        Project;
    string
        SegmentName;
    SEGMENT
        Segment;
    string
        GroupName;
    GROUP
        Group;
    PHASE
        Phase;
    SPRINT
        Sprint;
    Date
        Date_;
    string
        Name;
    bool
        HasDuration;
    long
        Duration;
    bool
        HasCompletion;
    long
        Completion;
    string
        Status;
    TASK[]
        SubtaskArray;
    long
        Indentation,
        Level;

    // -- CONSTRUCTORS

    this(
        )
    {
    }

    // ~~

    this(
        DEVELOPER developer,
        PROJECT project,
        string segment_name,
        string group_name,
        string name,
        Date date,
        long duration
        )
    {
        Developer = developer;
        Project = project;
        SegmentName = segment_name;
        GroupName = group_name;
        Name = name;
        Date_ = date;
        Duration = duration;
    }

    // -- INQUIRIES

    void Dump(
        )
    {
        writeln(
            Project.Name,
            ", ",
            SegmentName,
            ", ",
            GroupName,
            ", ",
            Developer.Name,
            ", ",
            GetDateText( Date_ ),
            ", ",
            Name,
            ", ",
            Duration
            );
    }
}

// ~~

class GROUP
{
    // -- ATTRIBUTES

    string
        Name;
    long
        Duration;
    TASK
        Task;

    // -- CONSTRUCTORS

    this(
        string name
        )
    {
        Name = name;
        Duration = 0;
    }
}

// ~~

class SEGMENT
{
    // -- ATTRIBUTES

    string
        Name;
    long
        Duration;
    TASK
        Task;
    GROUP[]
        GroupArray;
    GROUP[ string ]
        GroupByNameMap;

    // -- CONSTRUCTORS

    this(
        string name
        )
    {
        Name = name;
        Duration = 0;
        Task = null;
        GroupArray = [];
        GroupByNameMap = null;
    }

    // -- OPERATIONS

    GROUP GetGroup(
        string group_name
        )
    {
        GROUP
            group;

        if ( group_name in GroupByNameMap )
        {
            return GroupByNameMap[ group_name ];
        }
        else
        {
            group = new GROUP( group_name );

            GroupArray ~= group;
            GroupByNameMap[ group_name ] = group;

            return group;
        }
    }
}

// ~~

class PROJECT
{
    // -- ATTRIBUTES

    string
        Name;
    long
        Duration;
    long[ DEVELOPER ]
        DurationByDeveloperMap;
    TASK
        Task;
    SEGMENT[]
        SegmentArray;
    SEGMENT[ string ]
        SegmentByNameMap;
    PHASE[]
        PhaseArray;
    PHASE[ string ]
        PhaseByNameMap;

    // -- CONSTRUCTORS

    this(
        string name
        )
    {
        Name = name;
        Duration = 0;
        DurationByDeveloperMap = null;
        Task = null;
        SegmentArray = [];
        SegmentByNameMap = null;
        PhaseArray = [];
        PhaseByNameMap = null;
    }

    // -- OPERATIONS

    SEGMENT GetSegment(
        string segment_name
        )
    {
        SEGMENT
            segment;

        if ( segment_name in SegmentByNameMap )
        {
            return SegmentByNameMap[ segment_name ];
        }
        else
        {
            segment = new SEGMENT( segment_name );

            SegmentArray ~= segment;
            SegmentByNameMap[ segment_name ] = segment;

            return segment;
        }
    }

    // ~~

    PHASE GetPhase(
        string phase_name
        )
    {
        PHASE
            phase;

        if ( phase_name in PhaseByNameMap )
        {
            return PhaseByNameMap[ phase_name ];
        }
        else
        {
            phase = new PHASE( phase_name );

            PhaseArray ~= phase;
            PhaseByNameMap[ phase_name ] = phase;

            return phase;
        }
    }
}

// ~~

class DEVELOPER
{
    // -- ATTRIBUTES

    string
        Name;
    long
        Duration;
    long[ PROJECT ]
        DurationByProjectMap;

    // -- CONSTRUCTORS

    this(
        string name
        )
    {
        Name = name;
        Duration = 0;
        DurationByProjectMap = null;
    }
}

// ~~

class PHASE
{
    // -- ATTRIBUTES

    string
        Name;
    long
        Number,
        Duration;
    TASK[]
        TaskArray;

    // -- CONSTRUCTORS

    this(
        string name
        )
    {
        Name = name;
        Number = name.to!long();
        Duration = 0;
    }
}

// ~~

class SPRINT
{
    // -- ATTRIBUTES

    string
        Name;
    long
        Number,
        Duration;
    TASK[]
        TaskArray;

    // -- CONSTRUCTORS

    this(
        string name
        )
    {
        Name = name;
        Number = name.to!long();
        Duration = 0;
    }
}

// ~~

class TRACKING
{
    // -- ATTRIBUTES

    DEVELOPER[]
        DeveloperArray;
    DEVELOPER[ string ]
        DeveloperByNameMap;
    PROJECT[]
        ProjectArray;
    PROJECT[ string ]
        ProjectByNameMap;
    TASK[]
        TaskArray;
    TASK[][ Date ]
        TaskArrayByDateMap;
    long
        Duration;

    // -- CONSTRUCTORS

    this(
        )
    {
        DeveloperArray = [];
        DeveloperByNameMap = null;
        ProjectArray = [];
        ProjectByNameMap = null;
        TaskArray = [];
        TaskArrayByDateMap = null;
        Duration = 0;
    }

    // -- OPERATIONS

    DEVELOPER GetDeveloper(
        string developer_name
        )
    {
        DEVELOPER
            developer;

        if ( developer_name in DeveloperByNameMap )
        {
            return DeveloperByNameMap[ developer_name ];
        }
        else
        {
            developer = new DEVELOPER( developer_name );

            DeveloperArray ~= developer;
            DeveloperByNameMap[ developer_name ] = developer;

            return developer;
        }
    }

    // ~~

    PROJECT GetProject(
        string project_name
        )
    {
        PROJECT
            project;

        if ( project_name in ProjectByNameMap )
        {
            return ProjectByNameMap[ project_name ];
        }
        else
        {
            project = new PROJECT( project_name );

            ProjectArray ~= project;
            ProjectByNameMap[ project_name ] = project;

            return project;
        }
    }

    // ~~

    TASK AddTask(
        string developer_name,
        string project_name,
        string segment_name,
        string group_name,
        string task_name,
        Date task_date,
        long task_duration
        )
    {
        DEVELOPER
            developer;
        PROJECT
            project;
        TASK
            task;

        developer = GetDeveloper( developer_name );
        project = GetProject( project_name );
        task = new TASK( developer, project, segment_name, group_name, task_name, task_date, task_duration );

        TaskArray ~= task;

        if ( task_date !in TaskArrayByDateMap )
        {
            TaskArrayByDateMap[ task_date ] = [];
        }

        TaskArrayByDateMap[ task_date ] ~= task;

        return task;
    }

    // ~~

    void ReadFile(
        string input_file_path
        )
    {
        bool
            it_is_this_sprint;
        long
            line_index,
            parenthesis_character_index,
            task_duration,
            weekday_index;
        string
            developer_name,
            group_name,
            segment_name,
            line,
            project_name,
            task_name,
            trimmed_line,
            week_date_text,
            weekday_name;
        string[]
            line_array,
            part_array,
            task_time_array;
        Date
            monday_date,
            task_date;

        week_date_text = input_file_path.GetFileLabel().replace( '_', '-' );

        monday_date = GetMondayDate( week_date_text[ 0 .. 10 ] );

        line_array = input_file_path.ReadText().replace( "\r", "" ).replace( "\t", "    " ).split( '\n' );
        it_is_this_sprint = false;

        for ( line_index = 0;
              line_index < line_array.length;
              ++line_index )
        {
            line = line_array[ line_index ].stripRight();
            trimmed_line = line.stripLeft();

            if ( trimmed_line != "" )
            {
                if ( line.startsWith( '=' ) )
                {
                    developer_name = line.replace( "=", "" ).strip();

                    if ( developer_name == "" )
                    {
                        Abort( "Missing developer name", line, line_index );
                    }

                    it_is_this_sprint = false;
                }
                else if ( line.startsWith( "#" ) )
                {
                    if ( line.startsWith( "# This" ) )
                    {
                        it_is_this_sprint = true;
                    }
                    else if ( line.startsWith( "# Next" ) )
                    {
                        it_is_this_sprint = false;
                    }
                    else
                    {
                        Abort( "Invalid sprint syntax", line, line_index );
                    }
                }
                else if ( trimmed_line.startsWith( '-' ) )
                {
                    if ( it_is_this_sprint )
                    {
                        if ( line.startsWith( '-' ) )
                        {
                            segment_name = "";
                            group_name = "";
                        }

                        if ( line.startsWith( "  -" ) )
                        {
                            group_name = "";
                        }

                        if ( line.startsWith( '-' )
                             && line.endsWith( ':' ) )
                        {
                            segment_name = line[ 1 .. $ - 1 ].strip();
                        }
                        else if ( line.startsWith( "  -" )
                                  && line.endsWith( ':' ) )
                        {
                            group_name = line[ 3 .. $ - 1 ].strip();
                        }
                        else if ( line.endsWith( ')' ) )
                        {
                            parenthesis_character_index = trimmed_line.lastIndexOf( '(' );

                            if ( parenthesis_character_index >= 0 )
                            {
                                task_name = trimmed_line[ 1 .. parenthesis_character_index ].strip();
                                task_time_array = trimmed_line[ parenthesis_character_index + 1 .. $ - 1 ].split( ',' );

                                if ( task_time_array.length > 0 )
                                {
                                    foreach ( task_time; task_time_array )
                                    {
                                        part_array = task_time.strip().split( ' ' );

                                        if ( part_array.length == 1 )
                                        {
                                            weekday_name = part_array[ 0 ];
                                            task_duration = 0;
                                        }
                                        else if ( part_array.length == 2 )
                                        {
                                            weekday_name = part_array[ 0 ];
                                            task_duration = GetDuration( part_array[ 1 ] );
                                        }
                                        else
                                        {

                                            Abort( "Invalid task syntax : " ~ task_time, line, line_index );
                                        }

                                        weekday_index = GetWeekdayIndex( weekday_name );

                                        if ( developer_name == "" )
                                        {
                                            Abort( "Missing developer name", line, line_index );
                                        }
                                        else if ( project_name == "" )
                                        {
                                            Abort( "Missing project name", line, line_index );
                                        }
                                        else if ( weekday_index < 0 )
                                        {
                                            Abort( "Invalid weekday name", line, line_index );
                                        }
                                        else
                                        {
                                            task_date = GetIncrementedDate( monday_date, weekday_index );

                                            AddTask( developer_name, project_name, segment_name, group_name, task_name, task_date, task_duration );
                                        }
                                    }
                                }
                                else
                                {
                                    Abort( "Invalid task syntax", line, line_index );
                                }
                            }
                            else
                            {
                                Abort( "Invalid task syntax", line, line_index );
                            }
                        }
                    }
                }
                else
                {
                    project_name = trimmed_line;
                }
            }
        }
    }

    // ~~

    void ReadFiles(
        )
    {
        string
            input_file_label;
        string[]
            input_file_path_array;

        writeln( "Reading folder : ", InputFolderPath );

        foreach ( input_folder_entry; InputFolderPath.dirEntries( SpanMode.shallow ) )
        {
            if ( input_folder_entry.isFile )
            {
                input_file_path_array ~= input_folder_entry.name.GetLogicalPath();
            }
        }

        input_file_path_array.sort();

        foreach ( input_file_path; input_file_path_array )
        {
            if ( input_file_path.startsWith( InputFolderPath )
                 && input_file_path.endsWith( ".md" ) )
            {
                input_file_label = input_file_path.GetFileLabel();

                if ( !input_file_label.matchFirst( SprintReportFileLabelRegularExpression ).empty )
                {
                    ReadFile( input_file_path );
                }
                else if ( input_file_label != "backlog" )
                {
                    Abort( "Invalid file name : " ~ input_file_path );
                }
            }
        }
    }

    // ~~

    void SortDevelopers(
        )
    {
        DeveloperArray.sort!(
            ( a, b )
            {
                return a.Name < b.Name;
            }
            );
    }

    // ~~

    void SortProjects(
        )
    {
        ProjectArray.sort!(
            ( a, b )
            {
                return a.Name < b.Name;
            }
            );
    }

    // ~~

    void SortTasks(
        )
    {
        TaskArray.sort!(
            ( a, b )
            {
                if ( a.Date_ != b.Date_ )
                {
                    return a.Date_ < b.Date_;
                }
                else if ( a.Developer.Name != b.Developer.Name )
                {
                    return a.Developer.Name < b.Developer.Name;
                }
                else if ( a.Project.Name != b.Project.Name )
                {
                    return a.Project.Name < b.Project.Name;
                }
                else if ( a.SegmentName != b.SegmentName )
                {
                    return a.SegmentName < b.SegmentName;
                }
                else
                {
                    return a.Name < b.Name;
                }
            }
            );
    }

    // ~~

    void ProcessTasks(
        )
    {
        long
            remaining_duration,
            remaining_task_duration;
        TASK[]
            remaining_task_array;

        foreach ( date, ref task_array; TaskArrayByDateMap )
        {
            foreach ( developer; DeveloperArray )
            {
                remaining_task_array = [];
                remaining_duration = DayDuration;

                foreach ( task; task_array )
                {
                    if ( task.Developer == developer )
                    {
                        if ( task.Duration == 0 )
                        {
                            remaining_task_array ~= task;
                        }
                        else
                        {
                            remaining_duration -= task.Duration;
                        }
                    }
                }

                if ( remaining_task_array.length > 0
                     && remaining_duration > 0 )
                {
                    remaining_task_duration = remaining_duration / remaining_task_array.length;

                    if ( remaining_task_duration > 0 )
                    {
                        foreach ( remaining_task_index, remaining_task; remaining_task_array )
                        {
                            if ( remaining_task_index + 1 < remaining_task_array.length )
                            {
                                remaining_task.Duration = remaining_task_duration;
                                remaining_duration -= remaining_task_duration;
                            }
                            else
                            {
                                remaining_task.Duration = remaining_duration;
                            }
                        }
                    }
                }
            }
        }

        Duration = 0;

        foreach ( task; TaskArray )
        {
            task.Project.Duration += task.Duration;

            if ( task.Developer !in task.Project.DurationByDeveloperMap )
            {
                task.Project.DurationByDeveloperMap[ task.Developer ] = task.Duration;
            }
            else
            {
                task.Project.DurationByDeveloperMap[ task.Developer ] += task.Duration;
            }

            task.Developer.Duration += task.Duration;

            if ( task.Project !in task.Developer.DurationByProjectMap )
            {
                task.Developer.DurationByProjectMap[ task.Project ] = task.Duration;
            }
            else
            {
                task.Developer.DurationByProjectMap[ task.Project ] += task.Duration;
            }
        }
    }

    // ~~

    string GetTripleDurationText(
        long duration
        )
    {
        return
            duration.to!string()
            ~ '\t'
            ~ ( duration.to!double() / 60 ).to!string()
            ~ '\t'
            ~ ( duration.to!double() / DayDuration.to!double() ).to!string();
    }

    // ~~

    void WriteProjectTrackingFile(
        string output_file_path
        )
    {
        string[]
            line_array;

        line_array ~= "Project\tMinutes\tHours\tDays";

        foreach ( project; ProjectArray )
        {
            line_array
                ~= project.Name
                   ~ '\t'
                   ~ GetTripleDurationText( project.Duration );
        }

        output_file_path.WriteText( line_array.join( '\n' ) );
    }

    // ~~

    void WriteProjectDeveloperTrackingFile(
        string output_file_path
        )
    {
        string[]
            line_array;

        line_array ~= "Project\tDeveloper\tMinutes\tHours\tDays";

        foreach ( project; ProjectArray )
        {
            foreach ( developer; DeveloperArray )
            {
                if ( developer in project.DurationByDeveloperMap )
                {
                    line_array
                        ~= project.Name
                           ~ '\t'
                           ~ developer.Name
                           ~ '\t'
                           ~ GetTripleDurationText( project.DurationByDeveloperMap[ developer ] );
                }
            }
        }

        output_file_path.WriteText( line_array.join( '\n' ) );
    }

    // ~~

    void WriteDeveloperTrackingFile(
        string output_file_path
        )
    {
        string[]
            line_array;

        line_array ~= "Developer\tMinutes\tHours\tDays";

        foreach ( developer; DeveloperArray )
        {
            line_array
                ~= developer.Name
                   ~ '\t'
                   ~ GetTripleDurationText( developer.Duration );
        }

        output_file_path.WriteText( line_array.join( '\n' ) );
    }

    // ~~

    void WriteDeveloperProjectTrackingFile(
        string output_file_path
        )
    {
        string[]
            line_array;

        line_array ~= "Developer\tProject\tMinutes\tHours\tDays";

        foreach ( developer; DeveloperArray )
        {
            foreach ( project; ProjectArray )
            {
                if ( project in developer.DurationByProjectMap )
                {
                    line_array
                        ~= developer.Name
                           ~ '\t'
                           ~ project.Name
                           ~ '\t'
                           ~ GetTripleDurationText( developer.DurationByProjectMap[ project ] );
                }
            }
        }

        output_file_path.WriteText( line_array.join( '\n' ) );
    }

    // ~~

    void WriteTaskTrackingFile(
        string output_file_path
        )
    {
        string[]
            line_array;

        line_array ~= "Date\tWeekday\tDeveloper\tProject\tSegment\tGroup\tTask\tMinutes\tHours\tDays";

        foreach ( task; TaskArray )
        {
            line_array
                ~= GetDateText( task.Date_ )
                   ~ '\t'
                   ~ GetWeekdayName( task.Date_ )
                   ~ '\t'
                   ~ task.Developer.Name
                   ~ '\t'
                   ~ task.Project.Name
                   ~ '\t'
                   ~ task.SegmentName
                   ~ '\t'
                   ~ task.GroupName
                   ~ '\t'
                   ~ task.Name
                   ~ '\t'
                   ~ GetTripleDurationText( task.Duration );
        }

        output_file_path.WriteText( line_array.join( '\n' ) );
    }

    // ~~

    void WriteFiles(
        )
    {
        WriteDeveloperTrackingFile( OutputFolderPath ~ "developer_tracking.tsv" );
        WriteDeveloperProjectTrackingFile( OutputFolderPath ~ "developer_project_tracking.tsv" );
        WriteProjectTrackingFile( OutputFolderPath ~ "project_tracking.tsv" );
        WriteProjectDeveloperTrackingFile( OutputFolderPath ~ "project_developer_tracking.tsv" );
        WriteTaskTrackingFile( OutputFolderPath ~ "task_tracking.tsv" );
    }
}

// ~~

class PLANNING
{
    // -- ATTRIBUTES

    DEVELOPER[]
        DeveloperArray;
    DEVELOPER[ string ]
        DeveloperByNameMap;
    PROJECT[]
        ProjectArray;
    PROJECT[ string ]
        ProjectByNameMap;
    SPRINT[]
        SprintArray;
    SPRINT[ string ]
        SprintByNameMap;

    // -- CONSTRUCTORS

    this(
        )
    {
        DeveloperArray = [];
        DeveloperByNameMap = null;
        ProjectArray = [];
        ProjectByNameMap = null;
        SprintArray = [];
        SprintByNameMap = null;
    }

    // -- OPERATIONS

    DEVELOPER GetDeveloper(
        string developer_name
        )
    {
        DEVELOPER
            developer;

        if ( developer_name in DeveloperByNameMap )
        {
            return DeveloperByNameMap[ developer_name ];
        }
        else
        {
            developer = new DEVELOPER( developer_name );

            DeveloperArray ~= developer;
            DeveloperByNameMap[ developer_name ] = developer;

            return developer;
        }
    }

    // ~~

    PROJECT GetProject(
        string project_name
        )
    {
        PROJECT
            project;

        if ( project_name in ProjectByNameMap )
        {
            return ProjectByNameMap[ project_name ];
        }
        else
        {
            project = new PROJECT( project_name );

            ProjectArray ~= project;
            ProjectByNameMap[ project_name ] = project;

            return project;
        }
    }

    // ~~

    SPRINT GetSprint(
        string sprint_name
        )
    {
        SPRINT
            sprint;

        if ( sprint_name in SprintByNameMap )
        {
            return SprintByNameMap[ sprint_name ];
        }
        else
        {
            sprint = new SPRINT( sprint_name );

            SprintArray ~= sprint;
            SprintByNameMap[ sprint_name ] = sprint;

            return sprint;
        }
    }

    // ~~

    void ReadFile(
        string input_file_path
        )
    {
        char
            first_character;
        long
            line_index,
            parenthesis_character_index,
            task_index;
        string
            completion_text,
            duration_text,
            line,
            phase_name,
            project_name,
            sprint_name,
            task_name,
            task_text,
            trimmed_line;
        string[]
            line_array,
            part_array;
        PROJECT
            project;
        TASK
            task;
        TASK[]
            task_array;

        line_array = input_file_path.ReadText().replace( "\r", "" ).replace( "\t", "    " ).split( '\n' );

        for ( line_index = 0;
              line_index < line_array.length;
              ++line_index )
        {
            line = line_array[ line_index ].stripRight();
            trimmed_line = line.stripLeft();

            if ( trimmed_line != "" )
            {
                task = new TASK();

                if ( !trimmed_line.startsWith( '-' ) )
                {
                    project_name = trimmed_line;

                    if ( project_name != "" )
                    {
                        project = GetProject( project_name );

                        if ( project.Task is null )
                        {
                            project.Task = task;
                        }
                        else
                        {
                            task = project.Task;
                        }
                    }
                    else
                    {
                        Abort( "Invalid project syntax", line, line_index );
                    }

                    task.Indentation = -1;
                    task.Level = 0;

                    task_array = [ task ];
                }
                else
                {
                    if ( project !is null )
                    {
                        trimmed_line = trimmed_line[ 1 .. $ ].strip();

                        task.Indentation = line.indexOf( '-' );

                        for ( task_index = task_array.length - 1;
                              task_index >= 0 && task_array[ task_index ].Indentation >= task.Indentation;
                              --task_index )
                        {
                            task_array.length = task_index;
                        }

                        task.Level = task_array.length;

                        task_array[ $ - 1 ].SubtaskArray ~= task;
                        task_array ~= task;
                    }
                    else
                    {
                        Abort( "Missing project", line, line_index );
                    }
                }

                part_array = trimmed_line.split( ':' );

                if ( part_array.length == 1 )
                {
                    task_text = part_array[ 0 ].strip();
                }
                else if ( part_array.length == 2 )
                {
                    task_text = part_array[ 0 ].strip();
                    duration_text = part_array[ 1 ].strip();

                    if ( duration_text != "" )
                    {
                        if ( IsDuration( duration_text ) )
                        {
                            task.HasDuration = true;
                            task.Duration = GetDuration( duration_text );
                        }
                        else
                        {
                            Abort( "Invalid task duration", line, line_index );
                        }
                    }
                }
                else
                {
                    Abort( "Invalid task syntax", line, line_index );
                }

                if ( task_text.endsWith( ')' ) )
                {
                    parenthesis_character_index = task_text.indexOf( '(' );

                    if ( parenthesis_character_index >= 0 )
                    {
                        task.Name = task_text[ 0 .. parenthesis_character_index ].strip();
                        part_array = task_text[ parenthesis_character_index + 1 .. $ - 1 ].strip().split( ' ' );

                        foreach ( part; part_array )
                        {
                            if ( part.startsWith( '#' ) )
                            {
                                phase_name = part[ 1 .. $ ];

                                if ( IsPositiveInteger( phase_name ) )
                                {
                                    task.Phase = project.GetPhase( phase_name );
                                }
                                else
                                {
                                    Abort( "Invalid phase number", line, line_index );
                                }
                            }
                            else if ( part.startsWith( '!' ) )
                            {
                                sprint_name = part[ 1 .. $ ];

                                if ( IsPositiveInteger( sprint_name ) )
                                {
                                    task.Sprint = GetSprint( sprint_name );
                                }
                                else
                                {
                                    Abort( "Invalid sprint number", line, line_index );
                                }
                            }
                            else if ( part.endsWith( '%' ) )
                            {
                                completion_text = part[ 0 .. $ - 1 ];

                                if ( IsPositiveInteger( completion_text ) )
                                {
                                    task.HasCompletion = true;
                                    task.Completion = completion_text.to!long();
                                }
                                else
                                {
                                    Abort( "Invalid sprint number", line, line_index );
                                }
                            }
                            else
                            {
                                first_character = part[ 0 ];

                                if ( first_character >= 'a'
                                     && first_character <= 'z' )
                                {
                                    if ( task.Status == "" )
                                    {
                                        task.Status = part;
                                    }
                                    else
                                    {
                                        Abort( "Multiple states", line, line_index );
                                    }
                                }
                                else
                                {
                                    if ( task.Developer is null )
                                    {
                                        task.Developer = GetDeveloper( part );
                                    }
                                    else
                                    {
                                        Abort( "Multiple developers", line, line_index );
                                    }
                                }
                            }
                        }
                    }
                    else
                    {
                        Abort( "Invalid task data", line, line_index );
                    }
                }
                else
                {
                    task.Name = task_text;
                }

                task.Project = project;

                if ( task_array.length > 2
                     && task_array[ 1 ].Duration < 0 )
                {
                    task.SegmentName = task_array[ 1 ].Name;
                }

                task.Segment = project.GetSegment( task.SegmentName );

                if ( task_array.length > 3
                     && task_array[ 2 ].Duration < 0 )
                {
                    task.GroupName = task_array[ 2 ].Name;
                }

                task.Group = task.Segment.GetGroup( task.GroupName );
            }
        }
    }

    // ~~

    void ReadFiles(
        )
    {
        string[]
            input_file_path_array;

        writeln( "Reading folder : ", InputFolderPath );

        foreach ( input_folder_entry; InputFolderPath.dirEntries( SpanMode.shallow ) )
        {
            if ( input_folder_entry.isFile )
            {
                input_file_path_array ~= input_folder_entry.name.GetLogicalPath();
            }
        }

        input_file_path_array.sort();

        foreach ( input_file_path; input_file_path_array )
        {
            if ( input_file_path.startsWith( InputFolderPath )
                 && input_file_path.GetFileName() == "backlog.md" )
            {
                ReadFile( input_file_path );
            }
        }
    }

    // ~~

    void SortDevelopers(
        )
    {
        DeveloperArray.sort!(
            ( a, b )
            {
                return a.Name < b.Name;
            }
            );
    }

    // ~~

    void SortProjects(
        )
    {
        ProjectArray.sort!(
            ( a, b )
            {
                return a.Name < b.Name;
            }
            );
    }

    // ~~

    void SortSprints(
        )
    {
        SprintArray.sort!(
            ( a, b )
            {
                return a.Number < b.Number;
            }
            );
    }

    // ~~

    void ProcessTasks(
        TASK task
        )
    {
        foreach ( subtask; task.SubtaskArray )
        {
            ProcessTasks( subtask );

            task.Duration += subtask.Duration;
        }

        if ( task.Phase !is null )
        {
            task.Phase.Duration += task.Duration;
        }

        if ( task.Sprint !is null )
        {
            task.Sprint.Duration += task.Duration;
        }
    }

    // ~~

    void ProcessTasks(
        )
    {
        foreach ( project; ProjectArray )
        {
            ProcessTasks( project.Task );
        }
    }

    // ~~

    string GetTripleDurationText(
        long duration
        )
    {
        return
            ( duration.to!double() * MinimumDurationFactor / DayDuration.to!double() ).to!string()
            ~ '\t'
            ~ ( duration.to!double() * MediumDurationFactor / DayDuration.to!double() ).to!string()
            ~ '\t'
            ~ ( duration.to!double() * MaximumDurationFactor / DayDuration.to!double() ).to!string();
    }

    // ~~

    void WriteDeveloperPlanningFile(
        string output_file_path
        )
    {
        string[]
            line_array;

        line_array ~= "Developer\tProject\tSegment\tGroup\tTask\tMinutes\tHours\tDays";

        foreach ( developer; DeveloperArray )
        {
        }

        output_file_path.WriteText( line_array.join( '\n' ) );
    }

    // ~~

    void WriteProjectPlanningFile(
        string output_file_path
        )
    {
        string[]
            line_array;

        line_array ~= "Phase\tSprint\tProject\tSegment\tGroup\tTask\tMinimum Days\tMedium Days\tMaximum Days\tDeveloper\tStatus";

        foreach ( project; ProjectArray )
        {
        }

        output_file_path.WriteText( line_array.join( '\n' ) );
    }

    // ~~

    void WritePhasePlanningFile(
        string output_file_path
        )
    {
        string[]
            line_array;

        line_array ~= "Project\tSegment\tGroup\tTask\tMinimum Days\tMedium Days\tMaximum Days";

        foreach ( project; ProjectArray )
        {
            foreach ( phase; project.PhaseArray )
            {
            }
        }

        output_file_path.WriteText( line_array.join( '\n' ) );
    }

    // ~~

    void WriteSegmentPlanningFile(
        string output_file_path
        )
    {
        string[]
            line_array;

        line_array ~= "Project\tPhase\tSegment\tMinimum Days\tMedium Days\tMaximum Days";

        foreach ( project; ProjectArray )
        {
            foreach ( segment; project.SegmentArray )
            {
            }
        }

        output_file_path.WriteText( line_array.join( '\n' ) );
    }

    // ~~

    void WriteGroupPlanningFile(
        string output_file_path
        )
    {
        string[]
            line_array;

        line_array ~= "Project\tPhase\tSegment\tGroup\tMinimum Days\tMedium Days\tMaximum Days";

        foreach ( project; ProjectArray )
        {
            foreach ( segment; project.SegmentArray )
            {
                foreach ( group; segment.GroupArray )
                {
                }
            }
        }

        output_file_path.WriteText( line_array.join( '\n' ) );
    }

    // ~~

    void WriteSprintPlanningFile(
        string output_file_path
        )
    {
        string[]
            line_array;

        line_array ~= "Sprint\tMinutes\tHours\tDays";

        foreach ( sprint; SprintArray )
        {
        }

        output_file_path.WriteText( line_array.join( '\n' ) );
    }

    // ~~

    void WriteTaskPlanningFile(
        ref string[] line_array,
        TASK task
        )
    {
        long
            task_level;
        string
            task_name;

        if ( task.Level == 0 )
        {
            task_name = task.Name;
        }
        else
        {
            for ( task_level = 0;
                  task_level < task.Level;
                  ++task_level )
            {
                task_name ~= "  ";
            }

            task_name ~= "- " ~ task.Name;
        }

        line_array
            ~= ( ( task.Phase !is null ) ? task.Phase.Name : "" )
               ~ '\t'
               ~ ( ( task.Sprint !is null ) ? task.Sprint.Name : "" )
               ~ '\t'
               ~ task_name
               ~ '\t'
               ~ GetTripleDurationText( task.Duration )
               ~ '\t'
               ~ ( ( task.Developer !is null ) ? task.Developer.Name : "" )
               ~ '\t'
               ~ ( task.HasCompletion ? task.Completion.to!string() ~ '%' : "" )
               ~ '\t'
               ~ task.Status;

        foreach ( subtask; task.SubtaskArray )
        {
            WriteTaskPlanningFile( line_array, subtask );
        }
    }

    // ~~

    void WriteTaskPlanningFile(
        string output_file_path
        )
    {
        string[]
            line_array;

        line_array ~= "Phase\tSprint\tTask\tMinimum Days\tMedium Days\tMaximum Days\tDeveloper\tCompletion\tStatus";

        foreach ( project; ProjectArray )
        {
            WriteTaskPlanningFile( line_array, project.Task );
        }

        output_file_path.WriteText( line_array.join( '\n' ) );
    }

    // ~~

    void WriteFiles(
        )
    {
        WriteDeveloperPlanningFile( OutputFolderPath ~ "developer_planning.tsv" );
        WriteProjectPlanningFile( OutputFolderPath ~ "project_planning.tsv" );
        WritePhasePlanningFile( OutputFolderPath ~ "phase_planning.tsv" );
        WriteSegmentPlanningFile( OutputFolderPath ~ "segment_planning.tsv" );
        WriteGroupPlanningFile( OutputFolderPath ~ "group_planning.tsv" );
        WriteSprintPlanningFile( OutputFolderPath ~ "sprint_planning.tsv" );
        WriteTaskPlanningFile( OutputFolderPath ~ "task_planning.tsv" );
    }
}

// -- CONSTANTS

string[]
    WeekdayNameArray =
        [
            "Monday",
            "Tuesday",
            "Wednesday",
            "Thursday",
            "Friday",
            "Saturday",
            "Sunday",
            "Monday+",
            "Tuesday+",
            "Wednesday+",
            "Thursday+",
            "Friday+",
            "Saturday+",
            "Sunday+"
        ];
Regex!char
    PositiveIntegerRegularExpression = regex( r"^\d+$" ),
    PositiveRealRegularExpression = regex( r"^\d+\.?\d*$" ),
    MinuteDurationRegularExpression = regex( r"^\d+m$" ),
    HourDurationRegularExpression = regex( r"^\d+h$" ),
    HourMinuteDurationRegularExpression = regex( r"^\d+h\d+$" ),
    DayDurationRegularExpression = regex( r"^\d+\.?\d*d$" ),
    DateRegularExpression = regex( r"^\d{4}-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])$" ),
    SprintReportFileLabelRegularExpression = regex( r"^\d{4}_(0[1-9]|1[0-2])_(0[1-9]|[12]\d|3[01])$" );

// -- VARIABLES

long
    DayDuration = 8 * 60;
double
    MinimumDurationFactor,
    MediumDurationFactor,
    MaximumDurationFactor;
string
    InputFolderPath,
    OutputFolderPath;

// -- FUNCTIONS

void PrintError(
    string message
    )
{
    writeln( "*** ERROR : ", message );
}

// ~~

void Abort(
    string message
    )
{
    PrintError( message );

    exit( -1 );
}

// ~~

void Abort(
    string message,
    Exception exception
    )
{
    PrintError( message );
    PrintError( exception.msg );

    exit( -1 );
}

// ~~

void Abort(
    string message,
    string line,
    long line_index
    )
{
    writeln( "[", ( line_index + 1 ).to!string(), "] ", line );

    Abort( message );
}

// ~~

bool IsPositiveInteger(
    string text
    )
{
    return !text.matchFirst( PositiveIntegerRegularExpression ).empty;
}

// ~~

bool IsPositiveReal(
    string text
    )
{
    return !text.matchFirst( PositiveRealRegularExpression ).empty;
}

// ~~

string GetPhysicalPath(
    string path
    )
{
    version( Windows )
    {
        return `\\?\` ~ path.absolutePath.replace( '/', '\\' ).replace( "\\.\\", "\\" );
    }

    return path;
}

// ~~

string GetLogicalPath(
    string path
    )
{
    return path.replace( '\\', '/' );
}

// ~~

bool IsFolderPath(
    string text
    )
{
    return
        text == ""
        || text.GetLogicalPath().endsWith( '/' );
}

// ~~

string GetFolderPath(
    string file_path
    )
{
    long
        slash_character_index;

    slash_character_index = file_path.lastIndexOf( '/' );

    if ( slash_character_index >= 0 )
    {
        return file_path[ 0 .. slash_character_index + 1 ];
    }
    else
    {
        return "";
    }
}

// ~~

string GetFileName(
    string file_path
    )
{
    long
        slash_character_index;

    slash_character_index = file_path.lastIndexOf( '/' );

    if ( slash_character_index >= 0 )
    {
        return file_path[ slash_character_index + 1 .. $ ];
    }
    else
    {
        return file_path;
    }
}

// ~~

string GetFileLabel(
    string file_path
    )
{
    long
        dot_character_index;
    string
        file_name;

    file_name = GetFileName( file_path );
    dot_character_index = file_name.lastIndexOf( '.' );

    if ( dot_character_index >= 0 )
    {
        return file_name[ 0 .. dot_character_index ];
    }
    else
    {
        return file_name;
    }
}

// ~~

string GetFileExtension(
    string file_path
    )
{
    long
        dot_character_index;
    string
        file_name;

    file_name = GetFileName( file_path );
    dot_character_index = file_name.lastIndexOf( '.' );

    if ( dot_character_index >= 0 )
    {
        return file_name[ dot_character_index .. $ ];
    }
    else
    {
        return "";
    }
}

// ~~

void CreateFolder(
    string folder_path
    )
{
    try
    {
        if ( folder_path != ""
             && folder_path != "/"
             && !folder_path.exists() )
        {
            writeln( "Creating folder : ", folder_path );

            folder_path.GetPhysicalPath().mkdirRecurse();
        }
    }
    catch ( Exception exception )
    {
        Abort( "Can't create folder : " ~ folder_path, exception );
    }
}

// ~~

void WriteText(
    string file_path,
    string file_text
    )
{
    CreateFolder( file_path.GetFolderPath() );

    try
    {
        writeln( "Writing file : ", file_path );

        file_path.write( file_text );
    }
    catch ( Exception exception )
    {
        Abort( "Can't write file : " ~ file_path, exception );
    }
}

// ~~

string ReadText(
    string file_path
    )
{
    string
        file_text;

    writeln( "Reading file : ", file_path );

    try
    {
        file_text = file_path.readText();
    }
    catch ( Exception exception )
    {
        Abort( "Can't read file : " ~ file_path, exception );
    }

    return file_text;
}

// ~~

bool IsDuration(
    string text
    )
{
    return
        !text.matchFirst( MinuteDurationRegularExpression ).empty
        || !text.matchFirst( HourDurationRegularExpression ).empty
        || !text.matchFirst( HourMinuteDurationRegularExpression ).empty
        || !text.matchFirst( DayDurationRegularExpression ).empty;
}


// ~~

long GetDuration(
    string text
    )
{
    string[]
        part_array;

    if ( !text.matchFirst( MinuteDurationRegularExpression ).empty )
    {
        return text[ 0 .. $ - 1 ].to!long();
    }
    else if ( !text.matchFirst( HourDurationRegularExpression ).empty )
    {
        return text[ 0 .. $ - 1 ].to!long() * 60;
    }
    else if ( !text.matchFirst( HourMinuteDurationRegularExpression ).empty )
    {
        part_array = text.split( 'h' );

        return part_array[ 0 ].to!long() * 60 + part_array[ 1 ].to!long();
    }
    else if ( !text.matchFirst( DayDurationRegularExpression ).empty )
    {
        return ( text[ 0 .. $ - 1 ].to!double() * DayDuration.to!double() + 0.5 ).to!long();
    }
    else
    {
        Abort( "Invalid duration : " ~ text );

        return 0;
    }
}

// ~~

long GetWeekdayIndex(
    string weekday_name
    )
{
    return WeekdayNameArray.countUntil( weekday_name );
}

// ~~

string GetWeekdayName(
    long weekday_index
    )
{
    return WeekdayNameArray[ weekday_index ];
}

// ~~

bool IsDate(
    string text
    )
{
    return !text.matchFirst( DateRegularExpression ).empty;
}

// ~~

Date GetDate(
    string text
    )
{
    return Date.fromISOExtString( text );
}

// ~~

string GetDateText(
    Date date
    )
{
    return date.toISOExtString();
}

// ~~

long GetWeekdayIndex(
    Date date
    )
{
    return date.dayOfWeek;
}

// ~~

string GetWeekdayName(
    Date date
    )
{
    return GetWeekdayName( GetWeekdayIndex( date ) );
}

// ~~

Date GetIncrementedDate(
    Date date,
    long day_count
    )
{
    if ( day_count == 0 )
    {
        return date;
    }
    else
    {
        return date + days( day_count );
    }
}

// ~~

Date GetMondayDate(
    string date_text
    )
{
    Date
        date;

    date = GetDate( date_text );

    return GetIncrementedDate( date, -GetWeekdayIndex( date ) );
}

// ~~

void main(
    string[] argument_array
    )
{
    PLANNING
        planning;
    TRACKING
        tracking;

    argument_array = argument_array[ 1 .. $ ];

    if ( argument_array.length == 6
         && IsDuration( argument_array[ 0 ] )
         && IsPositiveReal( argument_array[ 1 ] )
         && IsPositiveReal( argument_array[ 2 ] )
         && IsPositiveReal( argument_array[ 3 ] )
         && IsFolderPath( argument_array[ 4 ] )
         && IsFolderPath( argument_array[ 5 ] ) )
    {
        DayDuration = GetDuration( argument_array[ 0 ] );
        MinimumDurationFactor = argument_array[ 1 ].to!double();
        MediumDurationFactor = argument_array[ 2 ].to!double();
        MaximumDurationFactor = argument_array[ 3 ].to!double();
        InputFolderPath = argument_array[ 4 ].GetLogicalPath();
        OutputFolderPath = argument_array[ 5 ].GetLogicalPath();

        tracking = new TRACKING();
        tracking.ReadFiles();
        tracking.SortDevelopers();
        tracking.SortProjects();
        tracking.SortTasks();
        tracking.ProcessTasks();
        tracking.WriteFiles();

        planning = new PLANNING();
        planning.ReadFiles();
        planning.SortDevelopers();
        planning.SortProjects();
        planning.SortSprints();
        planning.ProcessTasks();
        planning.WriteFiles();
    }
    else
    {
        writeln( "Usage :" );
        writeln( "    prism {workday duration} {minimum duration factor} {medium duration factor} {maximum duration factor} INPUT_FOLDER/ OUTPUT_FOLDER/" );
        writeln( "Example :" );
        writeln( "    prism 8h 1 1.5 2 INPUT_FOLDER/ OUTPUT_FOLDER/" );

        PrintError( "Invalid arguments : " ~ argument_array.to!string() );
    }
}
