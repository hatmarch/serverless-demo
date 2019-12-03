# Serverless (knative) Demo
===
## Concepts covered

1. OpenShift Serverless (1.0 Tech Preview)
2. OpenShift 4.2 Developer Perspective
3. Knative Eventing
4. Knative Kafka Eventing
5. (AMQStreams)
6. Quarkus

## About the demonstration application

Some information about the demo services therein:

* Catalog Service - A Spring boot application running on JBoss Web Server (Tomcat) and PostgreSQL, serves products and prices for retail products
* Cart Service - Quarkus application running on OpenJDK and native which manages shopping cart for each customer, together with inifnispan/JDG
* Inventory Service - Quarkus application running on OpenJDK and PostgreSQL, serves inventory and availability data for retail products
* Order service  - Quarkus application service running on OpenJDK or native for writing and displaying reviews for products
* User Service - Vert.x service running on JDK for managing users
* Payment Service  - A Quarkus based FaaS with Knative

## Walkthrough instructions

For demo walkthrough steps see [this setup guide](walkthrough/demo-setup.adoc) and [this walkthrough](walkthrough/demo-walkthrough.adoc)

## Acknowledgements

Adapted from [The CCN Roadshow(Dev Track) Module 4 Labs 2019](https://github.com/RedHat-Middleware-Workshops/cloud-native-workshop-v2m4-labs)