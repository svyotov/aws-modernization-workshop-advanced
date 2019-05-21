SHELL:=/bin/bash
PROJECT_DIR:=$(shell pwd)

build:
	docker-compose -f docker-compose.yml build petstore

run:
	docker-compose -f docker-compose.yml up -d postgres
	docker-compose -f docker-compose.yml up petstore

clean:
	docker-compose -f docker-compose.yml down -v
