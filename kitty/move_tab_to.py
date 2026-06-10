"""
Kitten to move the current tab to a specific position (1-indexed).
Insert logic: tabs shift to the right to make room.
"""
from kittens.tui.handler import result_handler
from kitty.boss import Boss


def main(args: list[str]) -> str:
    """Return the target position argument."""
    if len(args) > 1:
        return args[1]
    return "1"


@result_handler(no_ui=True)
def handle_result(
    args: list[str], answer: str, target_window_id: int, boss: Boss
) -> None:
    # answer comes from main() return value
    # args contains the original arguments passed to the kitten
    # Try answer first, then fall back to parsing args directly
    target_str = answer
    if not target_str:
        # Fallback: parse from args
        for arg in args:
            if arg.isdigit():
                target_str = arg
                break

    if not target_str:
        return

    try:
        # Parse target position (1-indexed from user)
        target_pos = int(target_str) - 1  # Convert to 0-indexed
    except (ValueError, TypeError):
        return

    # Get the active tab manager (current OS window's tabs)
    tm = boss.active_tab_manager
    if tm is None:
        return

    tabs = list(tm.tabs)
    total_tabs = len(tabs)
    if total_tabs <= 1:
        return

    # Find current tab position
    active_tab = tm.active_tab
    if active_tab is None:
        return

    current_pos = -1
    for i, tab in enumerate(tabs):
        if tab.id == active_tab.id:
            current_pos = i
            break

    if current_pos < 0:
        return

    # Clamp target to valid range
    target_pos = max(0, min(target_pos, total_tabs - 1))

    # Calculate moves needed
    delta = target_pos - current_pos

    if delta > 0:
        for _ in range(delta):
            tm.move_tab(1)  # Move forward
    elif delta < 0:
        for _ in range(-delta):
            tm.move_tab(-1)  # Move backward
