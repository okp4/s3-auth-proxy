package main

import (
	"github.com/rs/zerolog"
	"github.com/rs/zerolog/log"
	"okp4/s3-auth-proxy/cmd"
	"os"
)

func main() {
	log.Logger = log.Output(zerolog.ConsoleWriter{Out: os.Stderr})

	cmd.Execute()
}
