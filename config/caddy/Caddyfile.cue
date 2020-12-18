logging: logs: {
  default: exclude: ["http.log.access.log0"]
  log0: {
    include: ["http.log.access.log0"]
    writer: output: "stdout"
    encoder: {
      format: "formatted"
      template: #"{common_log} "{request>headers>Referer>[0]}" "{request>headers>User-Agent>[0]}""#
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
      browse: {}
    }]
  }]
  logs: default_logger_name: "log0"
}
