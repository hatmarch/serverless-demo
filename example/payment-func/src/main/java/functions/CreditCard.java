package functions;

public class CreditCard {
    public String number;
    public String expiration;
    public String nameOnCard;

    @Override
    public String toString() {
        // TODO Auto-generated method stub
        return String.format("Card No: %s for %s exp: %s",
            number, nameOnCard, expiration);
    }
}
