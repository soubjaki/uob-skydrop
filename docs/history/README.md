# History

Earlier plans and the files they came from, kept for the record. Nothing here is needed to run the project.

| Item | What it is |
| --- | --- |
| `roadmap-v1.md` | The first simulation plan (Sep 2026, Phases 0–9). Replaced by [`../roadmap.md`](../roadmap.md). |
| `teammate-archive/` | Text files from the team's migration archive of 23 Sep 2026, made when the X650 model was built on a team member's PC. |
| `teammate-archive/launchers/` | The original launch scripts. They used airframe `4001` (the stock x500), which loaded the wrong arm geometry; replaced by airframe 22001 and `simulation/run_x650_v2.sh`. |
| `teammate-archive/px4-state/` | PX4 and Gazebo-models git state at the time: commits (`px4_commit.txt`, `gz_commit.txt`), changed and untracked files, submodule list. |

Left out of the repo on purpose:

- `x650_skydrop_base_before_real_frame`: an exact copy of `x650_skydrop_base`.
- The duplicate mesh folders in `x650_skydrop_v2_base`: byte-identical to `x650_skydrop_base/meshes`, which is the one the model loads.
- `recovery/gz_complete_working_tree.tar.gz` (46 MB): a backup of PX4's Gazebo-models folder, rebuildable from the commits above.
- `uob_skydrop_px4.params`: a binary parameter dump holding only default calibration values.
