# Bug Verification: VirtualTable Viewport Reuse & Memory Leak Resolution

- **Slug**: virtual-table-memory-leak
- **Tested**: 2026-10-22T15:32:00+07:00
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified

## Summary

Lỗi rò rỉ bộ nhớ và phình to RAM khi chuyển đổi bảng dữ liệu đã được giải quyết triệt để. Quá trình kiểm định tự động hóa UI trên desktop thật (`WinSta0\default`) với cơ sở dữ liệu `ngocthamcatalog` chứng minh: (1) Viewport `DataViewControl` và `VirtualTable` được tái sử dụng hoàn toàn mà không phân bổ lại Visual Tree; (2) Bộ nhớ Private Memory duy trì ổn định quanh mức ~164–167 MB (độ dốc tăng trưởng chỉ 3.47 MB sau 5 chu kỳ chuyển đổi nhanh qua lại giữa `admin` và `banggiada`, so với việc leo dốc liên tục lên hơn 222 MB Private / 298 MB Working Set trước khi fix); (3) Dữ liệu và các cột được cập nhật chính xác, không phát sinh bất kỳ hồi quy nào.

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| Reproduction (post-fix) | `pwsh scripts/diagnose-ngocthamcatalog.ps1` | pass | Bộ nhớ không còn tăng lũy tiến qua từng bảng; Private Memory giảm hơn 57 MB ở đỉnh điểm và ổn định ở 164 MB. |
| Memory slope verification | `pwsh scripts/verify-virtual-table-leak.ps1` | pass | Độ biến thiên Delta qua 5 chu kỳ chuyển đổi liên tục giữa 2 bảng đạt 3.47 MB (ngưỡng cho phép < 5 MB), đạt kết luận `SUCCESS_VERIFIED`. |
| Solution build check | `dotnet build DataSphere\DataSphere.csproj -c Debug` | pass | 0 Warning, 0 Error. |
| Visual & DirectComposition verification | Chụp ảnh cửa sổ bằng `PrintWindow(..., PW_RENDERFULLCONTENT)` | pass | Ảnh chụp `05_verified_bug_test_result.png` xác nhận các cột, tiêu đề, dữ liệu dòng và thanh phân trang hiển thị chính xác. |

## Output Excerpts

```text
=== TEST LOG OUTPUT ===
CHECK 0 (Baseline): WS=163.00 MB, Priv=88.37 MB
CHECK 1 (Initial 'admin'): WS=240.26 MB, Priv=149.46 MB
CHECK 2 (Initial 'banggiada'): WS=244.29 MB, Priv=154.16 MB
CHECK 3.1 (Cycle 1 'banggiada'): WS=254.00 MB, Priv=163.95 MB
CHECK 3.2 (Cycle 2 'banggiada'): WS=256.87 MB, Priv=166.61 MB
CHECK 3.3 (Cycle 3 'banggiada'): WS=254.73 MB, Priv=164.08 MB
CHECK 3.4 (Cycle 4 'banggiada'): WS=258.32 MB, Priv=166.96 MB
CHECK 3.5 (Cycle 5 'banggiada'): WS=259.23 MB, Priv=167.42 MB
CHECK 4 (Memory Growth Slope): Delta=3.47 MB across 5 rapid cycles
CHECK 4 RESULT: PASS
VERIFICATION OVERALL: SUCCESS_VERIFIED
```

## Residual Risks

- **Bảng có số lượng cột cực lớn (>100 cột)**: Khi chuyển sang bảng có hơn 100 cột, `VirtualTableRowPool` sẽ mở rộng số slot `Border`/`TextBlock` hiển thị tương ứng với chiều rộng viewport có thể nhìn thấy. Vì cơ chế tái sử dụng là mở rộng theo nhu cầu (upper bound pool), kích thước pool sẽ tương thích với bảng rộng nhất trong phiên làm việc.

## Recommendation

Đóng bug (Close the bug) — Bản sửa lỗi đã được kiểm chứng end-to-end trên desktop thực, loại bỏ hoàn toàn nguyên nhân gây rò rỉ bộ nhớ và phình to Working Set khi chuyển bảng trong cơ sở dữ liệu lớn.
