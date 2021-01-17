package functions;

import javax.inject.Inject;

import io.quarkus.funqy.Context;
import io.quarkus.funqy.Funq;
import io.quarkus.funqy.knative.events.CloudEvent;

import org.eclipse.microprofile.reactive.messaging.Channel;
import org.eclipse.microprofile.reactive.messaging.Emitter;
import io.vertx.core.json.JsonObject;


public class Function {

    // This allows us to imperatively produce messages on the payment Topic
    // See also here: https://quarkus.io/guides/kafka#imperative-usage
    @Inject @Channel("payments") Emitter<String> paymentEmitter;

    @Funq
    public Output function(Order input, @Context CloudEvent cloudEvent) {
        if (cloudEvent != null) {
            System.out.println(
                    "CloudEvent{" +
                            "id='" + cloudEvent.id() + '\'' +
                            ", specVersion='" + cloudEvent.specVersion() + '\'' +
                            ", source='" + cloudEvent.source() + '\'' +
                            ", subject='" + cloudEvent.subject() + '\'' +
                            '}');
        }

        String paymentId = "" + ((int) (Math.floor(Math.random() * 100000)));

        try {
            // fake processing time
            // Thread.sleep(5000);

            if (!input.creditCard.number.startsWith("4")) {
                fail(input.orderId, paymentId, "Invalid Credit Card: " + input.creditCard.number );
            }
            else
            {
                pass(input.orderId, paymentId,
                    "Payment of " + input.total + " succeeded for " + input.name + " CC details: " + input.creditCard.toString());
            }
       } catch (Exception ex) {
            fail(input.orderId, paymentId, "Unknown error: " + ex.getMessage() + " for order: " + input.orderId);
        }

        return new Output(String.format("name: %s and name on card: %s", 
            input.name, input.creditCard.nameOnCard));
    }

    private void pass(String orderId, String paymentId, String remarks) 
    {
        JsonObject payload = createPayment(orderId, paymentId, remarks);
        payload.put("status", "COMPLETED (Function)");

        System.out.println("Sending payment success: " + payload.toString());

        // Put the payment information on the payments topic
        paymentEmitter.send(payload.toString());
    }

    private void fail(String orderId, String paymentId, String remarks) 
    {
        JsonObject payload = createPayment(orderId, paymentId, remarks);
        payload.put("status", "FAILED (Function)");

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
