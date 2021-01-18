package com.redhat.cloudnative;

import javax.inject.Inject;
import io.vertx.core.json.JsonObject;

import org.eclipse.microprofile.reactive.messaging.Channel;
import org.eclipse.microprofile.reactive.messaging.Emitter;

import javax.ws.rs.Consumes;
import javax.ws.rs.POST;
import javax.ws.rs.Path;
import javax.ws.rs.Produces;
import javax.ws.rs.core.MediaType;


@Path("/")
public class PaymentResource {

    // This allows us to imperatively produce messages on the payment Topic
    // See also here: https://quarkus.io/guides/kafka#imperative-usage
    @Inject @Channel("payments") Emitter<String> paymentEmitter;

    @POST
    @Produces(MediaType.TEXT_PLAIN)
    public void handleCloudEvent(String cloudEventJson) {
        String orderId = "unknown";
        String paymentId = "" + ((int) (Math.floor(Math.random() * 100000)));

        try 
        {
            System.out.println("received event: " + cloudEventJson);
            JsonObject event = new JsonObject(cloudEventJson);
            orderId = event.getString("orderId");
            String total = event.getString("total");
            JsonObject ccDetails = event.getJsonObject("creditCard");
            String name = event.getString("name");

            // fake processing time
            // Thread.sleep(5000);

            if (!ccDetails.getString("number").startsWith("4")) {
                fail(orderId, paymentId, "Invalid Credit Card: " + ccDetails.getString("number"));
            }
            else
            {
                pass(orderId, paymentId,
                "Payment of " + total + " succeeded for " + name + " CC details: " + ccDetails.toString());
            }
        } catch (Exception ex) {
            fail(orderId, paymentId, "Unknown error: " + ex.getMessage() + " for payment: " + cloudEventJson);
        }
    }

    private void pass(String orderId, String paymentId, String remarks) 
    {
        JsonObject payload = createPayment(orderId, paymentId, remarks);
        payload.put("status", "COMPLETED (Serverless Service)");

        System.out.println("Sending payment success: " + payload.toString());

        // Put the payment information on the payments topic
        paymentEmitter.send(payload.toString());
    }

    private void fail(String orderId, String paymentId, String remarks) 
    {
        JsonObject payload = createPayment(orderId, paymentId, remarks);
        payload.put("status", "FAILED (Serverless Service)");

        System.out.println("Sending payment failure: " + payload.toString());

        // Put the payment information on the payments topic
        paymentEmitter.send(payload.toString());
    }

    private JsonObject createPayment(String orderId, String paymentId, String remarks) 
    {
        JsonObject payload = new JsonObject();
        payload.put("orderId", orderId);
        payload.put("paymentId", paymentId);
        payload.put("remarks", remarks);

        return payload;
    }

}