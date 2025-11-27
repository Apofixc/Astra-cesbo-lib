local monitor = require "init_monitor"

pidfile("/var/run/tv3.pid")
-- log.set({ debug = true, stdout = true, filename = "/var/log/astra/tv3.log" })
log.set({ debug = true, stdout = true })



make_stream({
  name = "TV3",
  input =  {"http://31.130.202.110/httpts/tv3by/avchigh.ts"},
  output = { "udp://224.100.100.19:1234#sync&cbr=4",},
  monitor = {monitor_type = "ip"}
})

--Set_client_monitoring("127.0.0.1", 8080, "/channels")

-- make_monitor(nil, {
--   name = "TV 3",
--   monitor = "http://31.130.202.110/httpts/tv3by/avchigh.ts",
--   rate = 0.035,
--   time_update = 0,
--   analyze = false,
--   method_comparison = 3
-- })