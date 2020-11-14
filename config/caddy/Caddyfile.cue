logging: logs: {
  default: exclude: ["http.log.access.log0"]
  log0: {
    include: ["http.log.access.log0"]
    writer: output: "stdout"
    encoder: {
      format: "single_field"
      field:  "common_log"
    }
  }
}

apps: http: servers: srv0: {
  listen: [":2015"]
  routes: [{
    handle: [{
      handler: "vars"
      root:    "{env.CADDYWWWPATH}"
    }, {
      handler: "file_server"
      browse: {}
    }]
  }]
  logs: default_logger_name: "log0"
}
