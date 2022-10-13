+++
author = "Armel Soro"
date = 2020-02-28T20:49:35Z
description = ""
draft = true
slug = "resetting-micrometer-metrics-in-sprinboot-based-integration-tests"
title = "Reseting Micrometer metrics in SpringBoot-based integration tests"

+++


Context

The Problem

A solution

@Autowired private CollectorRegistry collectorRegistry;
  @Autowired private MeterRegistry meterRegistry;
  @Autowired private Collection<MonitoredService> monitoredServices;

  @Before
  public void beforeEachTest_RESTApplicationIntegrationTests() {
    this.meterRegistry.forEachMeter(
        new Consumer<Meter>() {
          @Override
          public void accept(Meter meter) {
            if (meter.getId().getName().startsWith("csm_")) {
              RESTApplicationIntegrationTests.this.meterRegistry.remove(meter);
            }
          }
        });
    this.collectorRegistry.clear();
    this.monitoredServices.forEach(monitoredService -> monitoredService.bindTo(this.meterRegistry));
  }



