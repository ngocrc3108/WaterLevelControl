# WaterLevelControl
- Bật máy bơm khi mực nước ở mức empty. tắt máy bơm khi mực nước ở mức high. Ở mỗi mức có 1 thời gian timeout khác nhau (mức empty là 10s, các mức còn lại là 20s). Khi timeout xảy ra thì bật còi hú, tắt máy bơm đồng thời hỏi người dùng có muốn tiếp tục (reset hệ thống) hay không. Chờ cho đến khi người dùng nhấn nút tiếp tục để khởi động lại hệ thống.
- Có 1 nút nhấn thực hiện 2 chức năng:
+  Không có timeout mức: chuyển đổi qua lại giữa chế độ bơm bình thường và nhanh (normal/high).
+  Khi timeout mức:  Reset hệ thống.
