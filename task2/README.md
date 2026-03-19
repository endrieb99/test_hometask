# Task 2 - Monitoring an SSL Offloading & Proxy Server

Before deciding what to monitor, I start by reading the specs, analyzing them and understanding the behavior. Doing this helps me understand what each component is doing under this workload. SSL offloading at 25,000 requests per second is a very specific kind of load. The server has one intensive job to terminate TLS connections and forward traffic to the backend. Knowing that upfront makes it clear where to focus. So rather than guessing, I looked at each spec to understand where things could go wrong.

Below is the server specs analysis.


## Server Specs Analysis

### 4 times Intel(R) Xeon(R) CPU E7-4830 v4 @ 2.00GHz

This CPU gives us 56 physical cores/112 threads in total (14 cores x 4 CPUs).

56 cores is solid, but TLS handshakes are expensive by nature, they require cryptographic operations that can't be skipped. At 25,000 requests per second, that load accumulates quickly and CPU becomes the first thing to watch.

The E7-4830 v4 has built-in hardware support for AES encryption called AES-NI, which makes TLS encryption much cheaper on the CPU. When it is active, the CPU handles everything very efficiently. When it is not, whether due to BIOS settings or misconfiguration, CPU does the same work much slower and we will see high CPU usage with no clear explanation why.

The main metrics I'd monitor on the CPU are overall CPU utilization, per-core breakdown, iowait, and CPU steal. Overall utilization gives a general health signal. In case it is sustained above 80%, then something needs attention. Per-core breakdown matters a lot because with 56 cores, the risk isn't just high CPU overall but uneven CPU distribution. If some cores are doing all the work while others are idle, the workload isn't being balanced properly across all 56 cores. iowait should stay close to zero in normal operations. If it starts climbing, the likely cause is the disk struggling to keep up with log writes, which ends up blocking the proxy workers. That's a disk problem showing up in CPU metrics, which makes it easy to misdiagnose. If this server is a VM, CPU steal is worth keeping an eye on. It means the hypervisor is quietly taking CPU cycles away from the server to serve other virtual machines. That lost compute hits crypto performance directly and impacts TLS performance with no visible trace in any other metric.

To verify AES-NI is actually active, two quick checks are worth running at setup time:

```bash
# Confirm AES-NI is available on the CPU
grep -m1 aes /proc/cpuinfo

# Confirm OpenSSL is actually using hardware acceleration
openssl speed -evp aes-128-gcm
```

The first command checks whether the CPU exposes AES-NI support. The second runs a real encryption speed test, if AES-NI is active, the numbers will be in the range of several GB/s. If OpenSSL is falling back to software, the numbers drop significantly. Both checks matter because a CPU can have AES-NI available while OpenSSL is still configured to ignore it.



### 64 GB RAM

64 GB is above what a proxy workload needs, which means that memory won't be the bottleneck here. However, there are two things that we can't ignore which are TLS session caching and proxy process memory growth over time.

**TLS session caching.** When a client reconnects, the server can recognize the previous session and skip the expensive handshake entirely. This is called session resumption and it significantly reduces CPU load. The session cache lives in memory. If it is well sized and working well, most of the connections will skip the expensive handshake. If the cache is too small or misconfigured, every connection does a full handshake and the CPU climbs unnecessarily.

**Proxy process memory growth over time.** A proxy running at high throughput for weeks can slowly grow in memory due to leaks or fragmentation. With 64 GB available this could go unnoticed for a long time until it becomes urgent.

The main metrics to monitor on the memory side are available memory, swap usage, proxy process RSS, and TLS session cache hit rate. Available memory should be tracked as a trend over time rather than just checking the current value. Swap usage must always be zero at this throughput. The moment the server starts swapping, latency spikes and the proxy becomes unreliable. Proxy process RSS should remain stable over time. A consistent upward trend with no clear cause is typically the first sign of a memory leak and it should be investigated before it impacts service availability. TLS session cache hit rate tells us how effectively the server is avoiding full handshakes. A high rate means fewer full handshakes and lower CPU pressure.



### 2 TB HDD

Out of all the specs, this one stands out as the most likely source of a subtle and hard to diagnose problem. A spinning hard disk is not fast. It has high latency and limited IOPS compared to SSDs. Under normal operation, the proxy does not use the disk. SSL offloading happens entirely in memory and over the network. But access logging does use the disk, and at 25,000 requests per second, that means a large volume of sequential writes hitting a slow disk constantly. If log writes are synchronous, proxy worker processes end up waiting on disk I/O. This shows up as iowait on CPU metrics and as increased response latency on the client side. There is no full disk, no disk error, just the proxy getting slower with no obvious explanation.

On the disk side, I would track 4 metrics which are iowait, disk write throughput, free disk space, and log rotation status. If iowait is consistently above 5%, the logging pipeline is likely the cause and it should be investigated before it starts affecting response times. Disk write throughput helps to understand how much log data is actually hitting the disk, which helps confirm whether the volume of writes is reasonable or excessive. Free disk space needs active alerting. At 25,000 requests per second logs fill disks faster than expected, so we set a warning at 80% and a critical alert at 90% which gives enough time to react before the disk is completely filled. Log rotation status makes sure it's running and actually reclaiming space. If it's broken or misconfigured without anyone noticing, logs will keep increasing until the disk is full and the proxy stops working.



### 2x10 Gbit/s NICs

20 Gbit/s total capacity is a lot of bandwidth for this workload. But the bandwidth isn't the main concern, connection state is. At 25,000 requests per second, the server is constantly opening and closing a large number of TCP connections. When a TCP connection closes, Linux doesn't immediately free the port. It holds the socket in TIME_WAIT for 60 seconds to prevent stale packets from being confused with new connections. At this request rate, closing connections constantly accumulate in TIME_WAIT. If the count gets high enough, the server exhausts its available local port range and can no longer open new connections, meanwhile CPU, memory, and bandwidth look normal. This is one of the least obvious failures for proxy servers and it is necessary to explicitly monitor TCP connection states to catch it.

Metrics I would analyze at this point are throughput per NIC, packet rate, NIC hardware errors and drops, and TCP connection state counts. Throughput per NIC gives a baseline of how much traffic each interface is handling. I would set a warning alert at 8 Gbit/s per interface to catch saturation before it becomes a problem. Packet rate is necessary to check because TLS produces many small packets, meaning that the packet rate can be high even when bandwidth looks fine. NIC hardware errors and drops are important to check because when the hardware drops packets, it doesn't appear in application logs, without detailed monitoring we wouldn't know it is happening. TCP connection state counts is the most important metric to check, more specifically TIME_WAIT and ESTABLISHED. We make a small check for that by using the `ss -s` command.

```bash
# Check TCP state distribution
ss -s
```

This command gives a real time snapshot of all TCP connection states on the server. At this request rate it is important to constantly check on TIME_WAIT. If it accumulates too much, the server runs out of available ports and new connections start failing, while everything else in the dashboard looks completely normal.


## Monitoring Set Up

For collection, I would use a Zabbix agent for all OS-level metrics including CPU, memory, disk, and network. For proxy-level I would scrape the proxy's own stats endpoint directly by using nginx stub_status. I would write a small Bash script using `ss -s` as a Zabbix user parameter for TCP state counts as it is not exposed by default. Regarding certificate expiry, I would use a script wrapping `openssl s_client` to feed the remaining days into alerting.

```bash
# Check SSL certificate expiry
echo | openssl s_client -connect localhost:443 2>/dev/null \
  | openssl x509 -noout -enddate
```

For visualization, I would use Grafana dashboards with dedicated panels for CPU per core, memory trend, active connections, request rate, error rate, TIME_WAIT count, and disk write throughput. The TIME_WAIT panel gets its own dedicated view because it's the one metric that fails silently without visibility.

For alerting, I would start with the following thresholds. On the CPU side, I would set a warning if utilization is sustained above 80%, and a separate warning if iowait is consistently above 5% since that points to the disk rather than the CPU itself. Swap usage getting above zero triggers an immediate critical alert, since at this throughput that should never happen. For the network, I would alert when TIME_WAIT count exceeds a defined baseline threshold, since by the time it's visible it's already close to causing failures. On the disk side, free disk space triggers a warning at 80% and escalates to critical at 90% because logs accumulate fast at this request rate and the gap between those two gives just enough time to react. At the application level, a spike in 5xx errors is an immediate critical alert since it means something is already broken for clients. Finally, for the SSL certificate I would set a warning at 30 days before expiry and escalate to critical at 7 days, since an expired certificate takes the service down completely and there needs to be enough time to act well before that happens.


## Challenges

**SSL handshake pressure is invisible in system metrics alone.** High CPU from TLS handshakes looks identical to high CPU from anything else in a generic dashboard. To understand the real cause, you need proxy-level metrics such as handshake rate and session resumption rate alongside system CPU, so you can correlate them in the same place. Without that, diagnosing a CPU spike during an incident means working without the full picture.

**TIME_WAIT exhaustion looks like a network failure with a healthy server**, meaning that it won't appear in standard dashboards. It requires an explicit TCP state check, otherwise it fails silently. CPU looks fine, memory looks fine, bandwidth looks fine, and the server just stops accepting new connections because the local port range is exhausted. Adding `ss -s` output as a monitored metric is a small effort that prevents a very confusing incident.

**The HDD logging bottleneck is easy to misdiagnose.** A full disk is obvious and easy to alert on. A slow disk quietly causing iowait and degrading proxy response times is much harder to spot without the right metrics in place. Monitoring has to surface the problem before you can solve it.

**Good alerting requires knowing what normal looks like first.** At 25,000 requests per second, baseline CPU and connection counts will look high to anyone unfamiliar with this server. Before locking in alert thresholds, I'd observe the system across different periods during peak traffic, off-peak, after a restart, and document what normal looks like. Alerts should trigger on deviations from normal, not just on large-looking numbers.



## Summary

| Spec | Key Risk | Primary Metric |
|------|----------|----------------|
| 4x Xeon E7-4830 v4 (56 cores) | TLS handshake load + AES-NI inactive | Per-core CPU, iowait, AES-NI check |
| 64 GB RAM | Session cache misconfigured, slow memory leak | Swap = 0, process RSS trend, cache hit rate |
| 2 TB HDD | Log writes blocking proxy workers | iowait, disk write throughput, free space |
| 2x10 Gbit/s NICs | TIME_WAIT port exhaustion | TCP state counts via ss -s |
