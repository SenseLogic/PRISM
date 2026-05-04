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
from dataclasses import ( dataclass, field );
from typing import ( Any, Iterable );

# -- CONSTANTS

DEFAULT_API = "https://api.monday.com/v2";
DEFAULT_API_VERSION = "2024-10";
TASK_PLANNING_GROUP_TITLE = "Backlog";

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

    # -- OPERATIONS

    def from_tsv_row(cls, row: dict[str, str], display_name: str) -> Task:

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

    def as_column_row(self) -> dict[str, str]:

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

# -- STATEMENTS

Task = dataclass( Task );
Task.from_tsv_row = classmethod( Task.from_tsv_row );

backlog_task = Task( name = "Backlog" );

# -- FUNCTIONS

def _leading_spaces(text: str) -> int:

    return len( text ) - len( text.lstrip( " " ) );

# ~~

def parse_task_cell(task_cell: str) -> tuple[int, str, bool] | None:

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

def read_tsv_rows(path: str) -> Iterable[dict[str, str]]:

    with open( path, newline = "", encoding = "utf-8-sig" ) as tsv_file:

        tsv_row_reader = csv.DictReader( tsv_file, delimiter = "\t" );

        if tsv_row_reader.fieldnames is None:

            raise SystemExit( "TSV has no header row." );

        normalized_header_by_header_map: dict[ str, str ] = { };

        for header in tsv_row_reader.fieldnames:

            if header is None:

                continue;

            normalized_header_by_header_map[ header ] = header.strip();

        for row in tsv_row_reader:

            normalized_row: dict[ str, str ] = { };

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

def build_column_values(
    row: dict[str, str],
    monday_columns_by_title: dict[str, str],
    *,
    include_estimate_days: bool = True,
    ) -> str | None:

    column_value_by_column_id_map: dict[ str, Any ] = { };

    def get_monday_column_id(column_title: str) -> str | None:

        monday_column_id = monday_columns_by_title.get( column_title );

        return (
            monday_column_id
            if ( monday_column_id
                 and monday_column_id not in { "name" } )
            else None
            );

    if include_estimate_days:

        for estimate_days_column_title in (
            "Minimum Days",
            "Medium Days",
            "Maximum Days",
            ):

            estimate_days_column_id = get_monday_column_id( estimate_days_column_title );

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

                column_value_by_column_id_map[ estimate_days_column_id ] = estimate_days_text;

    for always_include_column_title in (
        "Phase",
        "Sprint",
        "Developer",
        "Completion",
        "Status",
        ):

        always_include_column_id = get_monday_column_id( always_include_column_title );

        if not always_include_column_id:

            continue;

        always_include_column_value_text = row.get( always_include_column_title, "" ).strip();

        if not always_include_column_value_text:

            continue;

        if always_include_column_title in { "Phase", "Sprint" }:

            try:

                column_value_by_column_id_map[ always_include_column_id ] = (
                    float( always_include_column_value_text )
                    if "." in always_include_column_value_text
                    else int( always_include_column_value_text )
                    );

            except ValueError:

                column_value_by_column_id_map[ always_include_column_id ] = always_include_column_value_text;

        else:

            column_value_by_column_id_map[ always_include_column_id ] = always_include_column_value_text;

    if not column_value_by_column_id_map:

        return None;

    return json.dumps( column_value_by_column_id_map );

# ~~

def parse_task_planning_tsv(path: str) -> Task:

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

def print_task_tree(task: Task, depth: int = 0) -> None:

    label = (
        "backlog"
        if ( depth == 0
             and task.name == "Backlog" )
        else "task"
        );

    indentation_text = "  " * depth;
    print( f"{indentation_text}[{label}] {task.name!r}" );

    for subtask in task.subtask_list:

        print_task_tree( subtask, depth + 1 );

# -- TYPES

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

    def request(self, query: str, variables: dict[str, Any] | None = None) -> dict[str, Any]:

        request_body_bytes = json.dumps(
            {
                "query": query,
                "variables": variables or { },
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

    def list_groups(self, board_id: str) -> list[dict[str, Any]]:

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

        board_array = response_data.get( "boards" ) or [ ];

        if not board_array:

            raise SystemExit( f"Board not found or not visible: {board_id}" );

        return list( board_array[ 0 ].get( "groups" ) or [ ] );

    # ~~

    def create_group(self, board_id: str, group_name: str) -> str:

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

    def board_columns_by_title(self, board_id: str) -> dict[str, str]:
        query_text = """query ($ids: [ID!]) {
          boards(ids: $ids) {
            id
            columns { id title }
          }
        }""";

        response_data = self.request(
            query_text,
            {
                "ids": [ str( board_id ) ],
                },
            );

        board_array = response_data.get( "boards" ) or [ ];

        if not board_array:

            raise SystemExit( f"Board not found or not visible: {board_id}" );

        monday_column_array = board_array[ 0 ].get( "columns" ) or [ ];
        monday_column_id_by_monday_column_title_map: dict[ str, str ] = { };

        for monday_column in monday_column_array:

            monday_column_title = str( monday_column.get( "title", "" ) ).strip();
            monday_column_id = str( monday_column.get( "id", "" ) ).strip();

            if (
                monday_column_title
                and monday_column_id
                ):

                monday_column_id_by_monday_column_title_map[ monday_column_title ] = monday_column_id;

        return monday_column_id_by_monday_column_title_map;

    # ~~
    def create_item(
        self,
        board_id: str,
        group_id: str,
        name: str,
        column_values: str | None,
        ) -> str:

        mutation_text = """mutation ($board: ID!, $group: String!, $name: String!, $cols: JSON) {
          create_item(
            board_id: $board,
            group_id: $group,
            item_name: $name,
            column_values: $cols
          ) { id }
        }""";

        variables: dict[ str, Any ] = {
            "board": str( board_id ),
            "group": str( group_id ),
            "name": name,
            "cols": column_values if column_values is not None else "{}",
            };

        response_data = self.request( mutation_text, variables );
        return str( response_data[ "create_item" ][ "id" ] );

    def create_subitem(
        self,
        parent_item_id: str,
        name: str,
        column_values: str | None,
    ) -> str:
        mutation_text = """mutation ($parent: ID!, $name: String!, $cols: JSON) {
          create_subitem(
            parent_item_id: $parent,
            item_name: $name,
            column_values: $cols
          ) { id }
        }""";

        variables: dict[ str, Any ] = {
            "parent": str( parent_item_id ),
            "name": name,
            "cols": column_values if column_values is not None else "{}",
            };

        response_data = self.request( mutation_text, variables );
        return str( response_data[ "create_subitem" ][ "id" ] );

    # ~~

    def list_top_level_item_ids_in_group(self, board_id: str, group_id: str) -> list[str]:

        query_first_page_text = """query ($board: [ID!]!, $compare: [String!]) {
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
        }""";

        response_data = self.request(
            query_first_page_text,
            {
                "board": [ str( board_id ) ],
                "compare": [ str( group_id ) ],
                },
            );

        board_array = response_data.get( "boards" ) or [ ];

        if not board_array:

            return [ ];

        page = board_array[ 0 ].get( "items_page" ) or { };
        monday_item_id_array: list[ str ] = [ ];

        for monday_item in page.get( "items" ) or [ ]:

            monday_item_id_array.append( str( monday_item[ "id" ] ) );

        cursor = page.get( "cursor" );

        query_next_page_text = """query ($cursor: String!) {
          next_items_page(cursor: $cursor) {
            cursor
            items { id }
          }
        }""";

        while cursor:

            next_page_response_data = self.request(
                query_next_page_text,
                {
                    "cursor": cursor,
                    },
                );

            next_items_page = next_page_response_data.get( "next_items_page" ) or { };

            for monday_item in next_items_page.get( "items" ) or [ ]:

                monday_item_id_array.append( str( monday_item[ "id" ] ) );

            cursor = next_items_page.get( "cursor" );

        return monday_item_id_array;

    # ~~

    def delete_item(self, item_id: str) -> None:

        mutation_text = """mutation ($id: ID!) {
          delete_item(item_id: $id) { id }
        }""";

        self.request(
            mutation_text,
            {
                "id": str( item_id ),
                },
            );

# -- FUNCTIONS

def ensure_task_planning_group(client: MondayClient, board_id: str) -> tuple[str, bool]:

    for group in client.list_groups( board_id ):

        if str( group.get( "title", "" ) ).strip() == TASK_PLANNING_GROUP_TITLE:

            return str( group[ "id" ] ), False;

    group_id = client.create_group( board_id, TASK_PLANNING_GROUP_TITLE );
    return group_id, True;


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
    monday_columns_by_title: dict[str, str],
    delay_ms: int,
    ) -> None:

    # -- FUNCTIONS

    def column_json(task: Task) -> str | None:

        is_leaf_task = not task.subtask_list;

        return build_column_values(
            task.as_column_row(),
            monday_columns_by_title,
            include_estimate_days = is_leaf_task,
            );
    # ~~

    def upload_subtree(parent_monday_item_id: str, task: Task) -> None:

        for child_task in task.subtask_list:

            column_values_json = column_json( child_task );

            child_monday_item_id = client.create_subitem(
                parent_monday_item_id,
                child_task.name,
                column_values_json,
                );

            time.sleep( delay_ms / 1000.0 );
            upload_subtree( child_monday_item_id, child_task );

    # -- STATEMENTS

    for child_task in root.subtask_list:

        column_values_json = column_json( child_task );

        child_monday_item_id = client.create_item(
            board_id,
            group_id,
            child_task.name,
            column_values_json,
            );

        time.sleep( delay_ms / 1000.0 );
        upload_subtree( child_monday_item_id, child_task );

# ~~

def parse_args(argv: list[str]) -> argparse.Namespace:

    argument_parser = argparse.ArgumentParser(
        description = (
            'One-way sync: task_planning.tsv → board group "Backlog" (clear, then rebuild).'
            ),
        );

    argument_parser.add_argument(
        "tsv_path",
        help = "Path to task_planning.tsv",
        );

    argument_parser.add_argument(
        "--token",
        default = os.environ.get( "MONDAY_API_TOKEN", "" ),
        help = "monday API token (default: env MONDAY_API_TOKEN).",
        );

    argument_parser.add_argument(
        "--board-id",
        required = True,
        help = "Target board ID (from monday URL or API).",
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
        "--dry-run",
        action = "store_true",
        help = "Parse and print planned tree; do not call monday.",
        );

    return argument_parser.parse_args( argv );

# ~~

def main(argv: list[str]) -> int:

    args = parse_args( argv );

    if (
        not args.dry_run
        and not args.token.strip()
        ):

        print(
            "Missing API token: pass --token or set MONDAY_API_TOKEN.",
            file = sys.stderr,
            );

        return 2;

    parse_task_planning_tsv( args.tsv_path );

    if args.dry_run:

        print(
            f'(dry-run: no monday calls; a real run ensures group "{TASK_PLANNING_GROUP_TITLE}", clears it, then uploads.)',
            file = sys.stderr,
            );

        print_task_tree( backlog_task );
        return 0;

    client = MondayClient(
        args.token.strip(),
        args.api_url,
        args.api_version,
        );

    group_id, created = ensure_task_planning_group(
        client,
        args.board_id,
        );

    if created:

        print(
            f'Created group "{TASK_PLANNING_GROUP_TITLE}" ({group_id}).',
            file = sys.stderr,
            );

    monday_columns_by_title = client.board_columns_by_title( args.board_id );

    removed = clear_monday_group(
        client,
        args.board_id,
        group_id,
        args.delay_ms,
        );

    print(
        f"Cleared {removed} top-level item(s) in group {TASK_PLANNING_GROUP_TITLE!r} ({group_id}).",
        file = sys.stderr,
        );

    upload_backlog_to_monday(
        client,
        args.board_id,
        group_id,
        backlog_task,
        monday_columns_by_title,
        args.delay_ms,
        );

    return 0;

# -- STATEMENTS

if __name__ == "__main__":

    raise SystemExit( main( sys.argv[ 1: ] ) );
