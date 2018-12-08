# PingManager
Supports multiple pings at the same time, and greatly reduces thread resource consumption

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
