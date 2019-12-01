#!/bin/bash
oc tag --source docker mhildema/payment:v1 payment:v1
oc tag --source docker mhildema/cart:v1 cart:v1
oc tag --source docker mhildema/coolstore-ui:v1 coolstore-ui:v1
oc tag --source docker mhildema/inventory:v1 inventory:v1
oc tag --source docker mhildema/catalog:v1 catalog:v1