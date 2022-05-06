logging: logs: {
  default: exclude: ["http.log.access.log0"]
  log0: {
    include: ["http.log.access.log0"]
    writer: output: "stdout"
    encoder: {
      format: "transform"
      template: #"{request>remote_ip} - {request>user_id} [{ts}] "{request>method} {request>uri} {request>proto}" {status} {size} "{request>headers>Referer>[0]}" "{request>headers>User-Agent>[0]}""#
      time_format: "02/Jan/2006:15:04:05 -0700"
    }
  }
}

apps: http: servers: srv0: {
  listen: [":2015"]
  routes: [{
    handle: [{
      handler: "vars"
      root: "{$CADDYWWWPATH}"
    }, {
      handler: "file_server"
    }]
  }]
  logs: default_logger_name: "log0"
}
