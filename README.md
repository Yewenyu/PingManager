# PingManager
Supports multiple pings at the same time, and greatly reduces thread resource consumption

## CocoaPods
To include PingManager in a project using CocoaPods, you just add PingManager to your Podfile, for example:

    platform :ios, '10.0'

    target 'MyApp' do
        use_frameworks!
        pod 'PingManager'
    end


## Example
![1.gif](https://github.com/Yewenyu/PingManager/blob/master/1.gif) ![2.gif](https://github.com/Yewenyu/PingManager/blob/master/2.gif)
## Usage
```
for host in hostArray{
   let ping = Ping()
   ping.delegate = self
   ping.host = host
   PingMannager.shared.add(ping)
}
PingMannager.shared.setup {
   PingMannager.shared.timeout = self.timeout
   PingMannager.shared.pingPeriod = self.period
   PingMannager.shared.startPing()
}
```

