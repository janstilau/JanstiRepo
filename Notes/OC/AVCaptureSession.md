# AVCaptureSession

An object that manages capture activity and coordinates the flow of data from input devices to capture outputs.


* addInput
* addOuput

通过 [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio]; 取得 Device, 通过 Device 创建 Input. 然后添加 Output, Output 会通过代理方法, 将获取到的媒体数据进行输出.

You invoke startRunning to start the flow of data from the inputs to the outputs, and invoke stopRunning to stop the flow.