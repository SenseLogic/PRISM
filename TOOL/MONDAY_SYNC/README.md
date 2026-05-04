# Monday Sync

Creates a monday.com board group named `Task Planning` if it’s missing, clears its top-level items, then rebuilds the entire task tree from `task_planning.tsv`.

## Command line

```
python upload_task_planning.py TASK_PLANNING.tsv --board-id BOARD_ID [--token MONDAY_API_TOKEN] [--dry-run]
```

## Example

```bash
set MONDAY_API_TOKEN=your_token_here
python upload_task_planning.py ..\..\TEST\OUT\task_planning.tsv --board-id 1234567890
```
