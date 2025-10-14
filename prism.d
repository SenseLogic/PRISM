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
        this.Name = name;
        this.Duration = 0;
        this.DurationByProjectMap = null;
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

    // -- CONSTRUCTORS

    this(
        string name
        )
    {
        this.Name = name;
        this.Duration = 0;
        this.DurationByDeveloperMap = null;
    }
}

// ~~

class TASK
{
    // -- ATTRIBUTES

    PROJECT
        Project;
    string
        ModuleName;
    DEVELOPER
        Developer;
    Date
        Date_;
    string
        Name;
    long
        Duration;

    // -- CONSTRUCTORS

    this(
        DEVELOPER developer,
        PROJECT project,
        string module_name,
        string name,
        Date date,
        long duration
        )
    {
        this.Developer = developer;
        this.Project = project;
        this.ModuleName = module_name;
        this.Name = name;
        this.Date_ = date;
        this.Duration = duration;
    }

    // -- INQUIRIES

    void Dump(
        )
    {
        writeln(
            Project.Name,
            ", ",
            ModuleName,
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
        string module_name,
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
        task = new TASK( developer, project, module_name, task_name, task_date, task_duration );

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
            it_is_this_week;
        long
            line_index,
            parenthesis_character_index,
            task_duration,
            weekday_index;
        string
            developer_name,
            module_name,
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

        if ( week_date_text.length >= 10
             && IsDateText( week_date_text[ 0 .. 10 ] ) )
        {
            monday_date = GetMondayDate( week_date_text[ 0 .. 10 ] );

            line_array = input_file_path.ReadText().replace( "\r", "" ).replace( "\t", "    " ).split( '\n' );
            it_is_this_week = false;

            for ( line_index = 0;
                  line_index < line_array.length;
                  ++line_index )
            {
                line = line_array[ line_index ].stripRight();
                trimmed_line = line.stripLeft();

                writeln( "[", ( line_index + 1 ).to!string(), "] ", line );

                if ( line != "" )
                {
                    if ( line.startsWith( '=' ) )
                    {
                        developer_name = line.replace( "=", "" ).strip();
                    }
                    else if ( line.startsWith( "#" ) )
                    {
                        if ( line == "# This week" )
                        {
                            it_is_this_week = true;
                        }
                        else if ( line == "# Next week" )
                        {
                            it_is_this_week = false;
                        }
                        else
                        {
                            Abort( "Invalid week line" );
                        }
                    }
                    else if ( trimmed_line.startsWith( '-' ) )
                    {
                        if ( it_is_this_week )
                        {
                            if ( line.startsWith( '-' ) )
                            {
                                module_name = "";
                            }

                            if ( line.startsWith( '-' )
                                 && line.endsWith( ':' ) )
                            {
                                module_name = line[ 1 .. $ - 1 ].strip();
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

                                                Abort( "Invalid task time : " ~ task_time );
                                            }

                                            weekday_index = GetWeekdayIndex( weekday_name );

                                            if ( project_name != ""
                                                 && developer_name != ""
                                                 && weekday_index >= 0 )
                                            {
                                                task_date = GetIncrementedDate( monday_date, weekday_index );

                                                AddTask( developer_name, project_name, module_name, task_name, task_date, task_duration );
                                            }
                                            else
                                            {
                                                writeln( "Project name : ", project_name );
                                                writeln( "Developer name : ", developer_name );
                                                writeln( "Weekday name : ", weekday_name );

                                                Abort( "Invalid task line" );
                                            }
                                        }
                                    }
                                    else
                                    {
                                        Abort( "Invalid task line" );
                                    }
                                }
                                else
                                {
                                    Abort( "Invalid task line" );
                                }
                            }
                        }
                    }
                    else
                    {
                        project_name = line;
                    }
                }
            }
        }
        else
        {
            Abort( "Invalid file name" );
        }
    }

    // ~~

    void ReadFiles(
        string input_folder_path
        )
    {
        string[]
            input_file_path_array;

        writeln( "Reading folder : ", input_folder_path );

        foreach ( input_folder_entry; input_folder_path.dirEntries( SpanMode.shallow ) )
        {
            if ( input_folder_entry.isFile )
            {
                input_file_path_array ~= input_folder_entry.name.GetLogicalPath();
            }
        }

        input_file_path_array.sort();

        foreach ( input_file_path; input_file_path_array )
        {
            if ( input_file_path.startsWith( input_folder_path )
                 && input_file_path.endsWith( ".md" ) )
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
                else if ( a.ModuleName != b.ModuleName ) 
                {
                    return a.ModuleName < b.ModuleName;
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

    string GetDurationText(
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

    void WriteProjectFile(
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
                   ~ GetDurationText( project.Duration );
        }

        output_file_path.WriteText( line_array.join( '\n' ) );
    }

    // ~~

    void WriteProjectDeveloperFile(
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
                           ~ GetDurationText( project.DurationByDeveloperMap[ developer ] );
                }
            }
        }

        output_file_path.WriteText( line_array.join( '\n' ) );
    }

    // ~~

    void WriteDeveloperFile(
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
                   ~ GetDurationText( developer.Duration );
        }

        output_file_path.WriteText( line_array.join( '\n' ) );
    }

    // ~~

    void WriteDeveloperProjectFile(
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
                           ~ GetDurationText( developer.DurationByProjectMap[ project ] );
                }
            }
        }

        output_file_path.WriteText( line_array.join( '\n' ) );
    }

    // ~~

    void WriteTaskFile(
        string output_file_path
        )
    {
        string[]
            line_array;

        line_array ~= "Date\tWeekday\tDeveloper\tProject\tModule\tTask\tMinutes\tHours\tDays";

        SortTasks();

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
                   ~ task.ModuleName
                   ~ '\t'
                   ~ task.Name
                   ~ '\t'
                   ~ GetDurationText( task.Duration );
        }

        output_file_path.WriteText( line_array.join( '\n' ) );
    }

    // ~~

    void WriteFiles(
        string output_folder_path
        )
    {
        WriteDeveloperFile( output_folder_path ~ "developer.tsv" );
        WriteDeveloperProjectFile( output_folder_path ~ "developer_project.tsv" );
        WriteProjectFile( output_folder_path ~ "project.tsv" );
        WriteProjectDeveloperFile( output_folder_path ~ "project_developer.tsv" );
        WriteTaskFile( output_folder_path ~ "task.tsv" );
    }
}

// -- CONSTANTS

string[]
    WeekdayNameArray = [ "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday" ];
Regex!char
    MinuteDurationRegularExpression = regex( r"^\d+m$" ),
    HourDurationRegularExpression = regex( r"^\d+h$" ),
    HourMinuteDurationRegularExpression = regex( r"^\d+h\d+$" ),
    DayDurationRegularExpression = regex( r"^\d+\.?\d*d$" ),
    DateTextRegularExpression = regex( r"^\d{4}-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])$" );

// -- VARIABLES

long
    DayDuration = 8 * 60;

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

long GetDuration(
    string duration_text
    )
{
    string[]
        part_array;

    if ( !duration_text.matchFirst( MinuteDurationRegularExpression ).empty )
    {
        return duration_text[ 0 .. $ - 1 ].to!long();
    }
    else if ( !duration_text.matchFirst( HourDurationRegularExpression ).empty )
    {
        return duration_text[ 0 .. $ - 1 ].to!long() * 60;
    }
    else if ( !duration_text.matchFirst( HourMinuteDurationRegularExpression ).empty )
    {
        part_array = duration_text.split( 'h' );

        return part_array[ 0 ].to!long() * 60 + part_array[ 1 ].to!long();
    }
    else if ( !duration_text.matchFirst( DayDurationRegularExpression ).empty )
    {
        return ( duration_text[ 0 .. $ - 1 ].to!double() * DayDuration.to!double() + 0.5 ).to!long();
    }
    else
    {
        Abort( "Invalid duration : " ~ duration_text );

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

bool IsDateText(
    string date_text
    )
{
    return !date_text.matchFirst( DateTextRegularExpression ).empty;
}

// ~~

Date GetDate(
    string date_text
    )
{
    return Date.fromISOExtString( date_text );
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
    TRACKING
        tracking;

    argument_array = argument_array[ 1 .. $ ];

    if ( argument_array.length == 3
         && argument_array[ 1 ].GetLogicalPath().endsWith( '/' )
         && argument_array[ 2 ].GetLogicalPath().endsWith( '/' ) )
    {
        DayDuration = GetDuration( argument_array[ 0 ] );
        writeln( "Day duration : ", DayDuration, " minutes" );

        tracking = new TRACKING();
        tracking.ReadFiles( argument_array[ 1 ].GetLogicalPath() );
        tracking.SortDevelopers();
        tracking.SortProjects();
        tracking.SortTasks();
        tracking.ProcessTasks();
        tracking.WriteFiles( argument_array[ 2 ].GetLogicalPath() );
    }
    else
    {
        writeln( "Usage :" );
        writeln( "    prism INPUT_FOLDER/ OUTPUT_FOLDER/" );

        PrintError( "Invalid arguments : " ~ argument_array.to!string() );
    }
}
