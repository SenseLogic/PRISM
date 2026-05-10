# Monday Sync

Update the target multi-level board backlog group and rebuild the entire task tree from `task_planning.tsv`.

## Command line

```
python monday_sync.py prism_data_folder_path monday_multi_level_board_id monday_group_title [--token MONDAY_API_TOKEN] [--people] [--status] [--preview]
```

## Example

```bash
set MONDAY_API_TOKEN=your_token_here
python monday_sync.py PRISM_DATA_FOLDER/ 5095507480 "Backlog"
```

The board id is the number in the monday URL, e.g. `https://.../boards/5095507480`.

## Options

- `--people`: create `Developer` as a People column and assign by email/name
- `--status`: create `Status` as a monday Status column (otherwise it’s Text)
- `--preview`: print all board columns (title/id/type) and exit (also validates required columns)

## API version

This tool defaults to `API-Version: 2026-04` to support multi-level boards correctly. You can override with `--api-version` or `MONDAY_API_VERSION`.

## Columns

This script **does not delete or modify existing columns**.

- In normal mode, it validates required columns by title and **auto-creates any missing required columns** (board-level). If any required column has the wrong type, it aborts.
- In `--preview` mode, it validates required columns by title and **aborts** if any are missing or have the wrong type.

`Completion` is treated as **Text**. When a non-empty completion value is present in the TSV, it will be written as a string ending with `%` (e.g. `80%`).
