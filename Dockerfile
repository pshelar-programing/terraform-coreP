FROM golang:1.16 AS base

ENV GO111MODULE=on \
    CGO_ENABLED=0 \
    GOOS=linux \
    GOARCH=amd64 \
    GOPRIVATE=wwwin-github.cisco.com/learning-platform

WORKDIR /app

COPY . .

#add credentials on build
ARG GIT_USER
ARG GIT_TOKEN

##git to use token base auth when pulling go dependencies
RUN git config --global url."https://${GIT_USER}:${GIT_TOKEN}@wwwin-github.cisco.com".insteadOf "https://wwwin-github.cisco.com"

RUN go mod download

RUN go build -o terraform-infra-core .

FROM golang:1.16-alpine
WORKDIR /
COPY --from=base /app   /
ENTRYPOINT ["./terraform-infra-core", "serve"]
