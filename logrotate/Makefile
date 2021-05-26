IMAGE = maas-vault-logrotate
TAG = latest

build:
	docker build -t $(IMAGE):$(TAG) .

run: build
	docker run -it --name maas-vault-logrotate --rm --env CRON_SCHEDULE='$(CRON_SCHEDULE)' $(IMAGE):$(TAG)

sh: build
	docker run -it --name maas-vault-logrotate --rm $(IMAGE):$(TAG) sh
