@echo off
cd /d "%~dp0.."
python upload_task_planning.py "..\..\TEST\OUT\task_planning.tsv" --board-id 0 --dry-run
