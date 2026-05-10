# -- IMPORTS

from __future__ import annotations;

import argparse;
import csv;
import json;
import os;
import sys;
import time;
import urllib.error;
import urllib.request;

from dataclasses import (
    dataclass,
    field
    );

from typing import (
    Any,
    Iterable
    );

# -- CONSTANTS

DEFAULT_API = "https://api.monday.com/v2";
DEFAULT_API_VERSION = "2026-04";

# -- TYPES

class Task:

    # -- ATTRIBUTES

    phase: str = "";
    sprint: str = "";
    name: str = "";
    minimum_days: str = "";
    medium_days: str = "";
    maximum_days: str = "";
    developer: str = "";
    completion: str = "";
    status: str = "";
    subtask_list: list[ "Task" ] = field( default_factory = list );

    # -- INQUIRIES

    def is_backlog(
        self,
        depth: int,
        ) -> bool:

        return ( depth == 0 and self.name == "Backlog" );

    # ~~

    def is_group(
        self,
        depth: int,
        ) -> bool:

        return ( not self.is_backlog( depth ) and bool( self.subtask_list ) );

    # -- OPERATIONS

    def from_tsv_row(
        cls,
        row: dict[ str, str ],
        display_name: str,
        ) -> Task:

        return cls(
            phase = row.get( "Phase", "" ),
            sprint = row.get( "Sprint", "" ),
            name = display_name,
            minimum_days = row.get( "Minimum Days", "" ),
            medium_days = row.get( "Medium Days", "" ),
            maximum_days = row.get( "Maximum Days", "" ),
            developer = row.get( "Developer", "" ),
            completion = row.get( "Completion", "" ),
            status = row.get( "Status", "" ),
            );

    # ~~

    def as_column_row(
        self,
        ) -> dict[ str, str ]:

        return {
            "Phase": self.phase,
            "Sprint": self.sprint,
            "Task": self.name,
            "Minimum Days": self.minimum_days,
            "Medium Days": self.medium_days,
            "Maximum Days": self.maximum_days,
            "Developer": self.developer,
            "Completion": self.completion,
            "Status": self.status,
            };

# ~~

class MondayClient:

    # -- CONSTRUCTORS

    def __init__(
        self,
        token: str,
        base_url: str = DEFAULT_API,
        api_version: str = DEFAULT_API_VERSION,
        ) -> None:

        self.token = token;
        self.base_url = base_url.rstrip( "/" );
        self.api_version = api_version;

    # -- OPERATIONS

    def request(
        self,
        query: str,
        variables: dict[ str, Any ] | None = None,
        ) -> dict[ str, Any ]:

        request_body_bytes = json.dumps(
            {
                "query": query,
                "variables": variables or {},
                }
            ).encode( "utf-8" );

        request = urllib.request.Request(
            self.base_url,
            data = request_body_bytes,
            method = "POST",
            headers = {
                "Content-Type": "application/json",
                "Authorization": self.token,
                "API-Version": self.api_version,
                },
            );

        try:

            with urllib.request.urlopen( request, timeout = 120 ) as response:

                response_payload = json.loads( response.read().decode( "utf-8" ) );

        except urllib.error.HTTPError as http_error:

            error_detail_text = http_error.read().decode( "utf-8", errors = "replace" );
            raise SystemExit( f"HTTP {http_error.code}: {error_detail_text}" ) from http_error;

        if (
            "errors" in response_payload
            and response_payload[ "errors" ]
            ):

            error_message_text = "; ".join(
                str( graphql_error.get( "message", graphql_error ) )
                for graphql_error in response_payload[ "errors" ]
                );

            raise SystemExit( f"GraphQL errors: {error_message_text}" );

        if "data" not in response_payload:

            raise SystemExit( f"Unexpected response: {response_payload!r}" );

        return response_payload[ "data" ];

    # ~~

    def list_boards(
        self,
        limit: int = 100,
        maximum_page_count: int = 50,
        ) -> list[ dict[ str, Any ] ]:

        query_text = """query ($limit: Int!, $page: Int!) {
          boards(limit: $limit, page: $page) {
            id
            name
          }
        }""";

        board_list: list[ dict[ str, Any ] ] = [];

        for page in range( 1, maximum_page_count + 1 ):

            response_data = self.request(
                query_text,
                {
                    "limit": int( limit ),
                    "page": int( page ),
                    },
                );

            page_board_array = list( response_data.get( "boards" ) or [] );

            if not page_board_array:

                break;

            board_list.extend( page_board_array );

        return board_list;

    # ~~

    def board_id_by_name(
        self,
        board_name: str,
        ) -> str:

        normalized_target_name = str( board_name ).strip().casefold();

        if not normalized_target_name:

            raise SystemExit( "Board name is empty." );

        board_list = self.list_boards();

        matching_board_id_list = [
            str( board.get( "id" ) )
            for board in board_list
            if str( board.get( "name", "" ) ).strip().casefold() == normalized_target_name
            ];

        if not matching_board_id_list:

            raise SystemExit( f"Board not found or not visible: {board_name!r}" );

        if len( matching_board_id_list ) > 1:

            raise SystemExit(
                f"Multiple boards match {board_name!r}: {', '.join( matching_board_id_list )}"
                );

        return matching_board_id_list[ 0 ];

    # ~~

    def ensure_board_visible(
        self,
        board_id: str,
        ) -> None:

        board_id_text = str( board_id or "" ).strip();

        self.list_groups( board_id_text );

    # ~~

    def list_groups(
        self,
        board_id: str,
        ) -> list[ dict[ str, Any ] ]:

        query_text = """query ($ids: [ID!]) {
          boards(ids: $ids) {
            id
            groups { id title }
          }
        }""";

        response_data = self.request(
            query_text,
            {
                "ids": [ str( board_id ) ],
                },
            );

        board_array = response_data.get( "boards" ) or [];

        if not board_array:

            raise SystemExit( f"Board not found or not visible: {board_id}" );

        return list( board_array[ 0 ].get( "groups" ) or [] );

    # ~~

    def create_group(
        self,
        board_id: str,
        group_name: str,
        ) -> str:

        mutation_text = """mutation ($board: ID!, $name: String!) {
          create_group(board_id: $board, group_name: $name) {
            id
          }
        }""";

        response_data = self.request(
            mutation_text,
            {
                "board": str( board_id ),
                "name": str( group_name ),
                },
            );

        return str( response_data[ "create_group" ][ "id" ] );

    # ~~

    def board_columns_by_title(
        self,
        board_id: str,
        ) -> dict[ str, dict[ str, str ] ]:

        query_text = """query ($ids: [ID!]) {
          boards(ids: $ids) {
            id
            columns(capabilities: [null, CALCULATED, VISIBILITY]) { id title type settings_str }
          }
        }""";

        response_data = self.request(
            query_text,
            {
                "ids": [ str( board_id ) ],
                },
            );

        board_array = response_data.get( "boards" ) or [];

        if not board_array:

            raise SystemExit( f"Board not found or not visible: {board_id}" );

        monday_column_array = board_array[ 0 ].get( "columns" ) or [];
        monday_column_info_by_monday_column_title_map: dict[ str, dict[ str, str ] ] = {};

        for monday_column in monday_column_array:

            monday_column_title = str( monday_column.get( "title", "" ) ).strip();
            monday_column_id = str( monday_column.get( "id", "" ) ).strip();
            monday_column_type = str( monday_column.get( "type", "" ) ).strip();
            monday_column_settings_str = str( monday_column.get( "settings_str", "" ) or "" );

            if (
                monday_column_title
                and monday_column_id
                ):

                monday_column_info_by_monday_column_title_map[ monday_column_title ] = {
                    "id": monday_column_id,
                    "type": monday_column_type,
                    "settings_str": monday_column_settings_str,
                    };

        return monday_column_info_by_monday_column_title_map;

    # ~~

    def list_board_columns(
        self,
        board_id: str,
        ) -> list[ dict[ str, str ] ]:

        query_text = """query ($ids: [ID!]) {
          boards(ids: $ids) {
            id
            columns(capabilities: [null, CALCULATED, VISIBILITY]) { id title type settings_str }
          }
        }""";

        response_data = self.request(
            query_text,
            {
                "ids": [ str( board_id ) ],
                },
            );

        board_array = response_data.get( "boards" ) or [];

        if not board_array:

            raise SystemExit( f"Board not found or not visible: {board_id}" );

        column_array = board_array[ 0 ].get( "columns" ) or [];

        return [
            {
                "id": str( monday_column_dict.get( "id", "" ) ).strip(),
                "title": str( monday_column_dict.get( "title", "" ) ).strip(),
                "type": str( monday_column_dict.get( "type", "" ) ).strip(),
                "settings_str": str( monday_column_dict.get( "settings_str", "" ) or "" ),
                }
            for monday_column_dict in column_array
            if str( monday_column_dict.get( "id", "" ) ).strip()
            ];

    # ~~

    def infer_subitems_board_id(
        self,
        board_id: str,
        ) -> str | None:

        board_id_text = str( board_id ).strip();

        for monday_column_dict in self.list_board_columns( board_id ):

            monday_column_type_text = str( monday_column_dict.get( "type", "" ) ).strip().casefold();
            monday_column_title_text = str( monday_column_dict.get( "title", "" ) ).strip().casefold();

            if (
                monday_column_title_text == "subitems"
                or monday_column_type_text in { "subtasks", "subitems" }
                or str( monday_column_dict.get( "id", "" ) ).strip().startswith( "subtasks_" )
                ):

                settings_str = str( monday_column_dict.get( "settings_str", "" ) or "" ).strip();

                if not settings_str:

                    continue;

                try:

                    settings = json.loads( settings_str );

                except json.JSONDecodeError:

                    continue;

                candidate_id_list: list[ str ] = [];
                _collect_numeric_board_ids_from_json_value( settings, candidate_id_list );

                for candidate_id_text in candidate_id_list:

                    if (
                        candidate_id_text
                        and candidate_id_text.isdigit()
                        and candidate_id_text != board_id_text
                        ):

                        return candidate_id_text;

        # Fallback: infer from a real subitem if one exists.
        query_text = """query ($ids: [ID!]) {
          boards(ids: $ids) {
            items_page(limit: 1) {
              items {
                id
                subitems {
                  id
                  board { id }
                }
              }
            }
          }
        }""";

        response_data = self.request(
            query_text,
            {
                "ids": [ str( board_id ) ],
                },
            );

        board_array = response_data.get( "boards" ) or [];

        if not board_array:

            return None;

        items_page = board_array[ 0 ].get( "items_page" ) or {};
        item_array = items_page.get( "items" ) or [];

        if not item_array:

            return None;

        subitems = item_array[ 0 ].get( "subitems" ) or [];

        if not subitems:

            return None;

        subitem_board_dict = subitems[ 0 ].get( "board" ) or {};
        subitems_board_id = str( subitem_board_dict.get( "id", "" ) ).strip();
        return (
            subitems_board_id
            if ( subitems_board_id and subitems_board_id.isdigit() and subitems_board_id != board_id_text )
            else None
            );

    # ~~

    def create_column(
        self,
        board_id: str,
        title: str,
        column_type: str,
        ) -> str:

        column_type_text = str( column_type or "" ).strip();

        if not column_type_text:

            raise SystemExit( f"Column type is empty for column {title!r}." );

        mutation_text = """mutation ($board: ID!, $title: String!, $type: ColumnType!) {
          create_column(board_id: $board, title: $title, column_type: $type) {
            id
          }
        }""";

        response_data = self.request(
            mutation_text,
            {
                "board": str( board_id ),
                "title": str( title ),
                "type": column_type_text,
                },
            );

        return str( response_data[ "create_column" ][ "id" ] );

    # ~~

    def delete_column(
        self,
        board_id: str,
        column_id: str,
        ) -> None:

        mutation_text = """mutation ($board: ID!, $col: String!) {
          delete_column(board_id: $board, column_id: $col) { id }
        }""";

        self.request(
            mutation_text,
            {
                "board": str( board_id ),
                "col": str( column_id ),
                },
            );

    # ~~

    def change_column_title(
        self,
        board_id: str,
        column_id: str,
        title: str,
        ) -> None:

        mutation_text = """mutation ($board: ID!, $col: String!, $title: String!) {
          change_column_title(board_id: $board, column_id: $col, title: $title) { id }
        }""";

        self.request(
            mutation_text,
            {
                "board": str( board_id ),
                "col": str( column_id ),
                "title": str( title ),
                },
            );

    # ~~

    def list_users(
        self,
        limit: int = 500,
        ) -> list[ dict[ str, Any ] ]:

        query_text = """query ($limit: Int!) {
          users(limit: $limit) {
            id
            name
            email
          }
        }""";

        response_data = self.request(
            query_text,
            {
                "limit": int( limit ),
                },
            );

        return list( response_data.get( "users" ) or [] );

    # ~~

    def create_item(
        self,
        board_id: str,
        group_id: str,
        name: str,
        column_values: str | None,
        ) -> str:

        mutation_text = (
            """mutation ($board: ID!, $group: String!, $name: String!, $cols: JSON) {
            create_item(
                board_id: $board,
                group_id: $group,
                item_name: $name,
                column_values: $cols
            ) { id }
            }"""
            );

        variables: dict[ str, Any ] = {
            "board": str( board_id ),
            "group": str( group_id ),
            "name": name,
            "cols": column_values if column_values is not None else "{}",
            };

        response_data = self.request( mutation_text, variables );

        return str( response_data[ "create_item" ][ "id" ] );

    # ~~

    def create_subitem(
        self,
        parent_item_id: str,
        name: str,
        column_values: str | None,
        ) -> str:

        mutation_text = (
            """mutation ($parent: ID!, $name: String!, $cols: JSON) {
                create_subitem(
                    parent_item_id: $parent,
                    item_name: $name,
                    column_values: $cols
                ) { id }
            }"""
            );

        variables: dict[ str, Any ] = {
            "parent": str( parent_item_id ),
            "name": name,
            "cols": column_values if column_values is not None else "{}",
            };

        response_data = self.request( mutation_text, variables );

        return str( response_data[ "create_subitem" ][ "id" ] );

    # ~~

    def list_top_level_item_ids_in_group(
        self,
        board_id: str,
        group_id: str,
        ) -> list[ str ]:

        query_first_page_text = (
            """query ($board: [ID!]!, $compare: CompareValue!) {
                boards(ids: $board) {
                    items_page(
                    limit: 500,
                    query_params: {
                        rules: [
                        {
                            column_id: "group"
                            compare_value: $compare
                            operator: any_of
                        }
                        ]
                        operator: and
                    }
                    ) {
                    cursor
                    items { id }
                    }
                }
            }"""
            );

        response_data = self.request(
            query_first_page_text,
            {
                "board": [ str( board_id ) ],
                "compare": [ str( group_id ) ],
                },
            );

        board_array = response_data.get( "boards" ) or [];

        if not board_array:

            return [];

        page = board_array[ 0 ].get( "items_page" ) or {};
        monday_item_id_array: list[ str ] = [];

        for monday_item in page.get( "items" ) or []:

            monday_item_id_array.append( str( monday_item[ "id" ] ) );

        cursor = page.get( "cursor" );

        query_next_page_text = (
            """query ($cursor: String!) {
                next_items_page(cursor: $cursor) {
                    cursor
                    items { id }
                }
            }"""
            );

        while cursor:

            next_page_response_data = self.request(
                query_next_page_text,
                {
                    "cursor": cursor,
                    },
                );

            next_items_page = next_page_response_data.get( "next_items_page" ) or {};

            for monday_item in next_items_page.get( "items" ) or []:

                monday_item_id_array.append( str( monday_item[ "id" ] ) );

            cursor = next_items_page.get( "cursor" );

        return monday_item_id_array;

    # ~~

    def delete_item(
        self,
        item_id: str,
        ) -> None:

        mutation_text = (
            """mutation ($id: ID!) {
                delete_item(item_id: $id) { id }
            }"""
            );

        self.request(
            mutation_text,
            {
                "id": str( item_id ),
                },
            );

# -- FUNCTIONS

def _collect_numeric_board_ids_from_json_value(
    value: Any,
    numeric_id_out_list: list[ str ],
    ) -> None:

    if value is None:

        return;

    if isinstance( value, bool ):

        return;

    if isinstance( value, ( int, float ) ):

        numeric_text = str( int( value ) ).strip();

        if numeric_text.isdigit():

            numeric_id_out_list.append( numeric_text );

        return;

    if isinstance( value, str ):

        numeric_text = value.strip();

        if numeric_text.isdigit():

            numeric_id_out_list.append( numeric_text );

        return;

    if isinstance( value, dict ):

        for nested_value in value.values():

            _collect_numeric_board_ids_from_json_value( nested_value, numeric_id_out_list );

        return;

    if isinstance( value, list ):

        for nested_value in value:

            _collect_numeric_board_ids_from_json_value( nested_value, numeric_id_out_list );

        return;

# ~~

def _leading_spaces(
    text: str,
    ) -> int:

    return len( text ) - len( text.lstrip( " " ) );

# ~~

def parse_task_cell(
    task_cell: str,
    ) -> tuple[ int, str, bool ] | None:

    if task_cell is None:

        return None;

    task_cell_text = task_cell.replace( "\ufeff", "" ).rstrip( "\r\n" );

    if not task_cell_text.strip():

        return None;

    leading_space_count = _leading_spaces( task_cell_text );
    task_cell_tail_text = task_cell_text[ leading_space_count: ];

    if task_cell_tail_text.startswith( "- " ):

        task_title = task_cell_tail_text[ 2: ].strip();
        task_depth = 1 + ( leading_space_count // 2 );

        return ( task_depth, task_title, False );

    if task_cell_tail_text.startswith( "-" ):

        task_title = task_cell_tail_text[ 1: ].lstrip().strip();
        task_depth = 1 + ( leading_space_count // 2 );

        return ( task_depth, task_title, False );

    return ( 0, task_cell_text.strip(), True );

# ~~

def read_tsv_rows(
    path: str,
    ) -> Iterable[ dict[ str, str ] ]:

    with open( path, newline = "", encoding = "utf-8-sig" ) as tsv_file:

        tsv_row_reader = csv.DictReader( tsv_file, delimiter = "\t" );

        if tsv_row_reader.fieldnames is None:

            raise SystemExit( "TSV has no header row." );

        normalized_header_by_header_map: dict[ str, str ] = {};

        for header in tsv_row_reader.fieldnames:

            if header is None:

                continue;

            normalized_header_by_header_map[ header ] = header.strip();

        for row in tsv_row_reader:

            normalized_row: dict[ str, str ] = {};

            for column_name, column_value in row.items():

                normalized_column_name = normalized_header_by_header_map.get(
                    column_name,
                    column_name.strip(),
                    );

                raw_column_value_text = column_value or "";

                if normalized_column_name == "Task":

                    normalized_row[ normalized_column_name ] = raw_column_value_text.replace(
                        "\ufeff",
                        "",
                        ).rstrip( "\r\n" );

                else:

                    normalized_row[ normalized_column_name ] = raw_column_value_text.strip();

            yield normalized_row;

# ~~

def _monday_column_id_for_title(
    monday_columns_by_title: dict[ str, dict[ str, str ] ],
    column_title: str,
    ) -> str | None:

    monday_column_info = monday_columns_by_title.get( column_title ) or {};
    monday_column_id = str( monday_column_info.get( "id", "" ) ).strip();

    return (
        monday_column_id
        if ( monday_column_id
             and monday_column_id not in { "name" } )
        else None
        );

# ~~

def _monday_column_type_for_title(
    monday_columns_by_title: dict[ str, dict[ str, str ] ],
    column_title: str,
    ) -> str:

    monday_column_info = monday_columns_by_title.get( column_title ) or {};
    return str( monday_column_info.get( "type", "" ) ).strip();

# ~~

def build_column_values(
    row: dict[ str, str ],
    monday_columns_by_title: dict[ str, dict[ str, str ] ],
    *,
    include_estimate_days: bool = True,
    people_mode: bool = False,
    developer_text_column_title: str = "Developer",
    monday_user_id_by_email_map: dict[ str, str ] | None = None,
    monday_user_id_by_name_map: dict[ str, str ] | None = None,
    ) -> str | None:

    column_value_by_column_id_map: dict[ str, Any ] = {};

    if include_estimate_days:

        for estimate_days_column_title in (
            "Minimum Days",
            "Medium Days",
            "Maximum Days",
            ):

            estimate_days_column_id = _monday_column_id_for_title(
                monday_columns_by_title,
                estimate_days_column_title,
                );

            if not estimate_days_column_id:

                continue;

            estimate_days_text = row.get( estimate_days_column_title, "" ).strip();

            if not estimate_days_text:

                continue;

            try:

                column_value_by_column_id_map[ estimate_days_column_id ] = (
                    float( estimate_days_text )
                    if "." in estimate_days_text
                    else int( estimate_days_text )
                    );

            except ValueError:

                continue;

    for always_include_column_title in (
        "Phase",
        "Sprint",
        "Developer",
        "Completion",
        "Status",
        ):

        if always_include_column_title == "Developer":

            developer_value_text = row.get( "Developer", "" ).strip();

            if not developer_value_text:

                continue;

            developer_column_type = _monday_column_type_for_title( monday_columns_by_title, "Developer" );
            developer_people_column_id = _monday_column_id_for_title(
                monday_columns_by_title,
                "Developer",
                );

            if ( not people_mode ) and developer_column_type == "people":

                continue;

            if people_mode and developer_people_column_id and developer_column_type == "people":

                monday_user_id = "";

                if (
                    "@" in developer_value_text
                    and monday_user_id_by_email_map is not None
                    ):

                    monday_user_id = str(
                        monday_user_id_by_email_map.get( developer_value_text.casefold().strip(), "" )
                        ).strip();

                elif monday_user_id_by_name_map is not None:

                    monday_user_id = str(
                        monday_user_id_by_name_map.get( developer_value_text.casefold().strip(), "" )
                        ).strip();

                if not monday_user_id:

                    raise SystemExit(
                        (
                            f"Developer not found in monday users list: {developer_value_text!r}\n"
                            "Tip: pass an email address in the TSV or invite the user to your monday account."
                        )
                    );

                column_value_by_column_id_map[ developer_people_column_id ] = {
                    "personsAndTeams": [
                        { "id": int( monday_user_id ), "kind": "person" },
                        ],
                    };

                continue;

            always_include_column_id = _monday_column_id_for_title(
                monday_columns_by_title,
                always_include_column_title,
                );

        else:

            always_include_column_id = _monday_column_id_for_title(
                monday_columns_by_title,
                always_include_column_title,
                );

        if not always_include_column_id:

            continue;

        always_include_column_value_text = row.get( always_include_column_title, "" ).strip();

        if not always_include_column_value_text:

            continue;

        if always_include_column_title == "Completion":

            if not always_include_column_value_text.endswith( "%" ):

                always_include_column_value_text = always_include_column_value_text + "%";

        always_include_column_type = _monday_column_type_for_title(
            monday_columns_by_title,
            always_include_column_title,
            );

        if always_include_column_type == "status":

            column_value_by_column_id_map[ always_include_column_id ] = {
                "label": always_include_column_value_text,
                };
            continue;

        if always_include_column_type == "numbers":

            try:

                column_value_by_column_id_map[ always_include_column_id ] = (
                    float( always_include_column_value_text )
                    if "." in always_include_column_value_text
                    else int( always_include_column_value_text )
                    );

            except ValueError:

                continue;

        else:

            column_value_by_column_id_map[ always_include_column_id ] = always_include_column_value_text;

    if not column_value_by_column_id_map:

        return None;

    return json.dumps( column_value_by_column_id_map );

# ~~

def log_script_action(
    message: str,
    ) -> None:

    print( f"# {message}" );

# ~~

def task_column_values_json(
    task: Task,
    monday_columns_by_title: dict[ str, dict[ str, str ] ],
    *,
    people_mode: bool,
    monday_user_id_by_email_map: dict[ str, str ] | None,
    monday_user_id_by_name_map: dict[ str, str ] | None,
    ) -> str | None:

    is_leaf_task = not task.subtask_list;

    return build_column_values(
        task.as_column_row(),
        monday_columns_by_title,
        include_estimate_days = is_leaf_task,
        people_mode = people_mode,
        monday_user_id_by_email_map = monday_user_id_by_email_map,
        monday_user_id_by_name_map = monday_user_id_by_name_map,
        );

# ~~

def upload_task_subtree_to_monday(
    client: MondayClient,
    parent_monday_item_id: str,
    task: Task,
    depth: int,
    parent_monday_columns_by_title: dict[ str, dict[ str, str ] ],
    subitems_monday_columns_by_title: dict[ str, dict[ str, str ] ] | None,
    delay_ms: int,
    people_mode: bool,
    monday_user_id_by_email_map: dict[ str, str ] | None,
    monday_user_id_by_name_map: dict[ str, str ] | None,
    ) -> None:

    subitems_or_parent_columns_by_title = (
        subitems_monday_columns_by_title or parent_monday_columns_by_title
        );

    for child_task in task.subtask_list:

        label = "group" if child_task.subtask_list else "task";
        indentation_text = "  " * max( depth, 0 );
        log_script_action( f"Creating task: {indentation_text}[{label}] {child_task.name!r}" );

        column_values_json = task_column_values_json(
            child_task,
            subitems_or_parent_columns_by_title,
            people_mode = people_mode,
            monday_user_id_by_email_map = monday_user_id_by_email_map,
            monday_user_id_by_name_map = monday_user_id_by_name_map,
            );

        child_monday_item_id = client.create_subitem(
            parent_monday_item_id,
            child_task.name,
            column_values_json,
            );

        time.sleep( delay_ms / 1000.0 );
        upload_task_subtree_to_monday(
            client,
            child_monday_item_id,
            child_task,
            depth + 1,
            parent_monday_columns_by_title,
            subitems_monday_columns_by_title,
            delay_ms,
            people_mode,
            monday_user_id_by_email_map,
            monday_user_id_by_name_map,
            );

# ~~

def parse_task_planning_tsv(
    path: str,
    ) -> Task:

    global backlog_task;
    backlog_task = Task( name = "Backlog" );

    depth_by_stack_task_array: list[ tuple[ int, Task ] ] = [
        ( -1, backlog_task ),
        ];

    for tsv_row in read_tsv_rows( path ):

        parsed_task_cell = parse_task_cell( tsv_row.get( "Task", "" ) );

        if parsed_task_cell is None:

            continue;

        task_depth, task_title, is_project = parsed_task_cell;

        if not task_title:

            continue;

        task_node = Task.from_tsv_row( tsv_row, task_title );

        if is_project:

            while (
                depth_by_stack_task_array
                and depth_by_stack_task_array[ -1 ][ 0 ] >= 0
                ):

                depth_by_stack_task_array.pop();

            depth_by_stack_task_array[ -1 ][ 1 ].subtask_list.append( task_node );
            depth_by_stack_task_array.append( ( 0, task_node ) );
            continue;

        while (
            depth_by_stack_task_array
            and depth_by_stack_task_array[ -1 ][ 0 ] >= task_depth
            ):

            depth_by_stack_task_array.pop();

        if not depth_by_stack_task_array:

            raise SystemExit(
                f"TSV row has depth {task_depth} before any project row: {task_title!r}"
                );

        depth_by_stack_task_array[ -1 ][ 1 ].subtask_list.append( task_node );
        depth_by_stack_task_array.append( ( task_depth, task_node ) );

    return backlog_task;

# ~~

def print_task_tree(
    task: Task,
    depth: int = 0,
    ) -> None:

    is_backlog = task.is_backlog( depth );
    is_group = task.is_group( depth );

    label = (
        "backlog"
        if is_backlog
        else "group"
        if is_group
        else "task"
        );

    indentation_text = "  " * depth;
    print( f"{indentation_text}[{label}] {task.name!r}" );

    for subtask in task.subtask_list:

        print_task_tree( subtask, depth + 1 );

# ~~

def ensure_task_planning_group(
    client: MondayClient,
    board_id: str,
    monday_group_title: str,
    ) -> tuple[ str, bool ]:

    for group in client.list_groups( board_id ):

        if str( group.get( "title", "" ) ).strip() == monday_group_title:

            return str( group[ "id" ] ), False;

    group_id = client.create_group( board_id, monday_group_title );

    return group_id, True;

# ~~

def clear_monday_group(
    client: MondayClient,
    board_id: str,
    group_id: str,
    delay_ms: int,
    ) -> int:

    monday_item_id_array = client.list_top_level_item_ids_in_group( board_id, group_id );
    delay_seconds = delay_ms / 1000.0;

    for monday_item_id in monday_item_id_array:

        client.delete_item( monday_item_id );
        time.sleep( delay_seconds );

    return len( monday_item_id_array );

# ~~

def upload_backlog_to_monday(
    client: MondayClient,
    board_id: str,
    group_id: str,
    root: Task,
    parent_monday_columns_by_title: dict[ str, dict[ str, str ] ],
    subitems_monday_columns_by_title: dict[ str, dict[ str, str ] ] | None,
    delay_ms: int,
    people_mode: bool,
    ) -> None:

    monday_user_id_by_email_map: dict[ str, str ] | None = None;
    monday_user_id_by_name_map: dict[ str, str ] | None = None;

    if people_mode:

        monday_user_array = client.list_users();
        monday_user_id_by_email_map = {
            str( monday_user.get( "email", "" ) ).strip().casefold(): str(
                monday_user.get( "id", "" )
                ).strip()
            for monday_user in monday_user_array
            if str( monday_user.get( "email", "" ) ).strip()
            and str( monday_user.get( "id", "" ) ).strip()
            };
        monday_user_id_by_name_map = {
            str( monday_user.get( "name", "" ) ).strip().casefold(): str(
                monday_user.get( "id", "" )
                ).strip()
            for monday_user in monday_user_array
            if str( monday_user.get( "name", "" ) ).strip()
            and str( monday_user.get( "id", "" ) ).strip()
            };

    for child_task in root.subtask_list:

        label = "group" if child_task.subtask_list else "task";
        log_script_action( f"Creating task: [backlog::{label}] {child_task.name!r}" );

        column_values_json = task_column_values_json(
            child_task,
            parent_monday_columns_by_title,
            people_mode = people_mode,
            monday_user_id_by_email_map = monday_user_id_by_email_map,
            monday_user_id_by_name_map = monday_user_id_by_name_map,
            );

        child_monday_item_id = client.create_item(
            board_id,
            group_id,
            child_task.name,
            column_values_json,
            );

        time.sleep( delay_ms / 1000.0 );
        upload_task_subtree_to_monday(
            client,
            child_monday_item_id,
            child_task,
            1,
            parent_monday_columns_by_title,
            subitems_monday_columns_by_title,
            delay_ms,
            people_mode,
            monday_user_id_by_email_map,
            monday_user_id_by_name_map,
            );

# ~~

def parse_arguments(
    argument_value_array: list[ str ],
    ) -> argparse.Namespace:

    argument_parser = argparse.ArgumentParser(
        description = (
            "One-way sync: task_planning.tsv -> board group (clear, then rebuild)."
            ),
        );

    argument_parser.add_argument(
        "prism_data_folder_path",
        help = "Path to PRISM data folder containing task_planning.tsv",
        );

    argument_parser.add_argument(
        "monday_multi_level_board_id",
        help = "Target monday multilevel board id (numeric; copy from monday URL).",
        );

    argument_parser.add_argument(
        "monday_group_title",
        help = "Target monday group title.",
        );

    argument_parser.add_argument(
        "--token",
        default = os.environ.get( "MONDAY_API_TOKEN", "" ),
        help = "monday API token (default: env MONDAY_API_TOKEN).",
        );

    argument_parser.add_argument(
        "--api-url",
        default = os.environ.get( "MONDAY_API_URL", DEFAULT_API ),
        help = f"GraphQL endpoint (default: {DEFAULT_API} or env MONDAY_API_URL).",
        );

    argument_parser.add_argument(
        "--api-version",
        default = os.environ.get( "MONDAY_API_VERSION", DEFAULT_API_VERSION ),
        help = "API-Version header value.",
        );

    argument_parser.add_argument(
        "--delay-ms",
        type = int,
        default = 200,
        help = "Sleep between create calls (default 200).",
        );

    argument_parser.add_argument(
        "--people",
        dest = "people",
        action = "store_true",
        help = (
            "Interpret TSV 'Developer' as a monday user (email preferred, else exact name) "
            "and assign it to a People column. If omitted, 'Developer' is treated as free text."
            ),
        );

    argument_parser.add_argument(
        "--status",
        dest = "status",
        action = "store_true",
        help = (
            "Create the 'Status' column as a monday Status column. "
            "If omitted, 'Status' is created as a Text column so arbitrary values are accepted."
            ),
        );

    argument_parser.add_argument(
        "--preview",
        dest = "preview",
        action = "store_true",
        help = "Parse and print planned tree; do not call monday.",
        );

    return argument_parser.parse_args( argument_value_array );

# ~~

def main(
    argument_value_array: list[ str ],
    ) -> int:

    arguments = parse_arguments( argument_value_array );

    if ( not arguments.token.strip() ):

        print(
            "Missing API token: pass --token or set MONDAY_API_TOKEN.",
            file = sys.stderr,
            );

        return 2;

    prism_data_folder_path = os.path.abspath( str( arguments.prism_data_folder_path ) );
    task_planning_file_path = (
        prism_data_folder_path
        if prism_data_folder_path.lower().endswith( ".tsv" )
        else os.path.join( prism_data_folder_path, "task_planning.tsv" )
        );

    client = MondayClient(
        arguments.token.strip(),
        arguments.api_url,
        arguments.api_version,
        );

    board_id = str( arguments.monday_multi_level_board_id or "" );

    if ( not board_id ) or ( not board_id.isdigit() ):

        raise SystemExit(
            (
                f"Board id must be numeric, got: {board_id!r}\n"
                "Tip: the board id is the number in the monday URL, e.g. "
                "`https://.../boards/5095507480`."
            )
        );

    board_id = board_id.strip();
    client.ensure_board_visible( board_id );

    if arguments.preview:

        ensure_monday_required_columns(
            client,
            board_id,
            allow_create = False,
            developer_column_as_people = arguments.people,
            status_as_monday_status = arguments.status,
            );

        return 0;

    parent_columns_by_title, subitems_columns_by_title, subitems_board_id = (
        ensure_monday_required_columns(
            client,
            board_id,
            allow_create = True,
            developer_column_as_people = arguments.people,
            status_as_monday_status = arguments.status,
            )
        );

    log_script_action( f"Reading task planning file: {task_planning_file_path}" );
    parse_task_planning_tsv( task_planning_file_path );
    print_task_tree( backlog_task );

    group_id, created = ensure_task_planning_group(
        client,
        board_id,
        arguments.monday_group_title,
        );

    if created:

        print(
            f'Created group "{arguments.monday_group_title}" ({group_id}).',
            file = sys.stderr,
            );

    log_script_action( f"Clearing group: {arguments.monday_group_title!r} ({group_id})" );

    removed = clear_monday_group(
        client,
        board_id,
        group_id,
        arguments.delay_ms,
        );

    print(
        (
            f"Cleared {removed} top-level item(s) in group "
            f"{arguments.monday_group_title!r} ({group_id})."
            ),
        file = sys.stderr,
        );

    upload_backlog_to_monday(
        client,
        board_id,
        group_id,
        backlog_task,
        parent_columns_by_title,
        subitems_columns_by_title,
        arguments.delay_ms,
        arguments.people,
        );

    return 0;

# -- STATEMENTS

Task = dataclass( Task );
Task.from_tsv_row = classmethod( Task.from_tsv_row );

# ~~

@dataclass
class Column:

    title: str;
    column_id: str;
    column_type: str;
    scope: str = "PARENT";  # or "SUBITEMS"

    @property
    def key(
        self,
        ) -> str:

        return (
            f"SUBITEMS::{self.title}"
            if self.scope == "SUBITEMS"
            else self.title
            );

# ~~

def _duplicate_monday_column_title_sort_key(
    title_and_duplicate_columns_pair: tuple[ str, list[ dict[ str, str ] ] ],
    ) -> str:

    return title_and_duplicate_columns_pair[ 0 ].casefold();

# ~~

def dump_monday_board_columns(
    client: MondayClient,
    label: str,
    board_id_text: str,
    *,
    scope: str,
    ) -> list[ dict[ str, str ] ]:

    log_script_action( f"Getting column list: {label}" );
    monday_column_dict_array = client.list_board_columns( board_id_text );
    print( f"# {label} columns: {len( monday_column_dict_array )}" );

    for monday_column_dict in monday_column_dict_array:

        monday_column_id_text = str( monday_column_dict.get( "id", "" ) ).strip();
        monday_column_type_text = str( monday_column_dict.get( "type", "" ) ).strip().casefold();
        monday_column_title_text = str( monday_column_dict.get( "title", "" ) ).strip();

        if (
            monday_column_title_text.strip().casefold() == "subitems"
            or monday_column_id_text.startswith( "subtasks_" )
            or monday_column_type_text in { "subtasks", "subitems" }
            ):

            settings_str = str( monday_column_dict.get( "settings_str", "" ) or "" );
            settings_preview = settings_str.strip().replace( "\r", " " ).replace( "\n", " " );

            if len( settings_preview ) > 240:

                settings_preview = settings_preview[ : 240 ] + "...";

            print(
                f"# {scope} Subitems settings_str len={len(settings_str)} preview={settings_preview!r}"
                );

    monday_column_dict_list_by_title_map: dict[ str, list[ dict[ str, str ] ] ] = {};

    for monday_column_dict in monday_column_dict_array:

        column_title_text = str( monday_column_dict.get( "title", "" ) ).strip();
        monday_column_dict_list_by_title_map.setdefault( column_title_text, [] ).append(
            monday_column_dict
            );

    duplicate_title_and_columns_pair_array = [
        (
            column_title_key,
            monday_column_dict_list_by_title_map[ column_title_key ],
            )
        for column_title_key in monday_column_dict_list_by_title_map
        if column_title_key
        and len( monday_column_dict_list_by_title_map[ column_title_key ] ) > 1
        ];

    if duplicate_title_and_columns_pair_array:

        print(
            f"# {label} duplicate titles: {len( duplicate_title_and_columns_pair_array )}"
            );

        for column_title_text, duplicate_monday_column_dict_array in sorted(
            duplicate_title_and_columns_pair_array,
            key = _duplicate_monday_column_title_sort_key,
            ):

            column_signature_text = ", ".join(
                (
                    str( duplicate_monday_column_dict.get( "id", "" ) ).strip()
                    + ":"
                    + str( duplicate_monday_column_dict.get( "type", "" ) ).strip()
                    )
                for duplicate_monday_column_dict in duplicate_monday_column_dict_array
                );

            print(
                f"# DUPLICATE {scope}::{column_title_text}\t{column_signature_text}"
                );

    for monday_column_dict in monday_column_dict_array:

        column_record = Column(
            title = str( monday_column_dict.get( "title", "" ) ),
            column_id = str( monday_column_dict.get( "id", "" ) ),
            column_type = str( monday_column_dict.get( "type", "" ) ),
            scope = scope,
            );

        print(
            f"{column_record.key}\t{column_record.column_id}\t{column_record.column_type}"
            );

    return monday_column_dict_array;

# ~~

def ensure_monday_required_columns(
    client: MondayClient,
    board_id: str,
    *,
    allow_create: bool,
    developer_column_as_people: bool,
    status_as_monday_status: bool,
    ) -> tuple[
        dict[ str, dict[ str, str ] ],
        dict[ str, dict[ str, str ] ] | None,
        str | None,
    ]:

    dump_monday_board_columns( client, "Parent board", board_id, scope = "PARENT" );

    subitems_board_id = client.infer_subitems_board_id( board_id );
    print( f"# Inferred subitems board id: {subitems_board_id!r}" );

    if subitems_board_id:

        dump_monday_board_columns(
            client,
            f"Subitems board ({subitems_board_id})",
            subitems_board_id,
            scope = "SUBITEMS",
            );

    expected_column_type_by_title_map: dict[ str, str ] = {
        "Phase": "numbers",
        "Sprint": "numbers",
        "Minimum Days": "numbers",
        "Medium Days": "numbers",
        "Maximum Days": "numbers",
        "Developer": "people" if developer_column_as_people else "text",
        "Completion": "text",
        "Status": "status" if status_as_monday_status else "text",
        };

    parent_columns = client.list_board_columns( board_id );
    subitems_columns = (
        client.list_board_columns( subitems_board_id )
        if subitems_board_id
        else []
        );

    column_array: list[ Column ] = [
        Column(
            title = str( parent_monday_column_dict.get( "title", "" ) ),
            column_id = str( parent_monday_column_dict.get( "id", "" ) ),
            column_type = str( parent_monday_column_dict.get( "type", "" ) ),
            scope = "PARENT",
            )
        for parent_monday_column_dict in parent_columns
        ];

    for subitem_monday_column_dict in subitems_columns:

        column_array.append(
            Column(
                title = str( subitem_monday_column_dict.get( "title", "" ) ),
                column_id = str( subitem_monday_column_dict.get( "id", "" ) ),
                column_type = str( subitem_monday_column_dict.get( "type", "" ) ),
                scope = "SUBITEMS",
                )
            );

    wrong_type_errors: list[ str ] = [];
    missing_titles: list[ str ] = [];

    for expected_title, expected_type in expected_column_type_by_title_map.items():

        matching_column_record_array = [
            column_record for column_record in column_array
            if column_record.key in { expected_title, f"SUBITEMS::{expected_title}" }
            and column_record.title.strip() == expected_title
            ];

        if matching_column_record_array:

            existing_types = sorted(
                {
                    column_record.column_type.strip()
                    for column_record in matching_column_record_array
                    if column_record.column_type.strip()
                    }
                );

            if len( existing_types ) != 1:

                wrong_type_errors.append(
                    f"Multiple types for title {expected_title!r}: {existing_types!r}"
                    );

                continue;

            if existing_types[ 0 ] != expected_type:

                wrong_type_errors.append(
                    f"Wrong type for title {expected_title!r}: got {existing_types[0]!r}, expected {expected_type!r}"
                    );

                continue;

            continue;

        missing_titles.append( expected_title );

    if wrong_type_errors:

        raise SystemExit(
            "Column type errors:\n- " + "\n- ".join( wrong_type_errors )
            );

    if missing_titles and ( not allow_create ):

        raise SystemExit(
            "Missing required columns:\n- "
            + "\n- ".join( missing_titles )
            );

    if missing_titles and allow_create:

        log_script_action( f"Creating missing columns: {', '.join( missing_titles )}" );

        for missing_column_title in missing_titles:

            log_script_action(
                f"Creating column: {missing_column_title!r} ({expected_column_type_by_title_map[ missing_column_title ]})"
                );

            client.create_column(
                board_id,
                missing_column_title,
                expected_column_type_by_title_map[ missing_column_title ],
                );

    return (
        client.board_columns_by_title( board_id ),
        client.board_columns_by_title( subitems_board_id ) if subitems_board_id else None,
        subitems_board_id,
        );

backlog_task = Task( name = "Backlog" );

if __name__ == "__main__":

    raise SystemExit( main( sys.argv[ 1: ] ) );
