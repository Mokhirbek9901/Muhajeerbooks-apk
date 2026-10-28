import 'package:flutter_test/flutter_test.dart';
import 'package:muhajeerbooks/app_state.dart';
import 'package:muhajeerbooks/store_ui.dart';

void main() {
  final pickupQuote=<String,dynamic>{
    'customer_name':'Test Customer',
    'phone':'01012345678',
    'delivery_type':'경산 직접수령',
    'address':'경산 직접수령 (Gyeongsan pickup)',
    'subtotal':21000,
    'delivery_fee':0,
    'total':21000,
  };

  test('Gyeongsan pickup: short optional address matches canonical server quote', () {
    expect(checkoutQuoteContactMatches(
      quote:pickupQuote,customerName:'Test Customer',
      phone:'01012345678',address:'경산 직접수령',
      deliveryType:'경산 직접수령',
    ),isTrue);
    expect(isGyeongsanPickupAddress('', '경산 직접수령'),'경산 직접수령');
    expect(pickupQuote['total'],21000);
    expect(pickupQuote['delivery_fee'],0);
  });

  test('Gyeongsan pickup: a real typed address must match exactly', () {
    final realAddress={...pickupQuote, 'address':'경산시 어느길 123-3'};
    expect(checkoutQuoteContactMatches(
      quote:realAddress,customerName:'Test Customer',
      phone:'01012345678',address:'경산시 어느길 123-3',
      deliveryType:'경산 직접수령',
    ),isTrue);
    expect(checkoutQuoteContactMatches(
      quote:realAddress,customerName:'Test Customer',
      phone:'01012345678',address:'경산 직접수령',
      deliveryType:'경산 직접수령',
    ),isFalse);
  });

  test('No customer identity or delivery-type changes are bypassed', () {
    expect(checkoutQuoteContactMatches(
      quote:pickupQuote,customerName:'Another Customer',
      phone:'01012345678',address:'경산 직접수령',
      deliveryType:'경산 직접수령',
    ),isFalse);
    expect(checkoutQuoteContactMatches(
      quote:pickupQuote,customerName:'Test Customer',
      phone:'01000000000',address:'경산 직접수령',
      deliveryType:'경산 직접수령',
    ),isFalse);
    expect(checkoutQuoteContactMatches(
      quote:pickupQuote,customerName:'Test Customer',
      phone:'01012345678',address:'경산 직접수령',
      deliveryType:'택배',
    ),isFalse);
  });

  test('Ordinary Korean shipping still requires exact quoted address', () {
    final deliveryQuote={...pickupQuote,
      'delivery_type':'택배',
      'address':'경산시 어느길 123-3',
      'delivery_fee':4000,'total':25000};
    expect(checkoutQuoteContactMatches(
      quote:deliveryQuote,customerName:'Test Customer',
      phone:'01012345678',address:'경산시 어느길 123-3',
      deliveryType:'택배',
    ),isTrue);
    expect(checkoutQuoteContactMatches(
      quote:deliveryQuote,customerName:'Test Customer',
      phone:'01012345678',address:'경산 직접수령',
      deliveryType:'택배',
    ),isFalse);
  });

  test('Proof upload visible without manual quote, for both pickup and courier', () {
    expect(checkoutProofSectionVisible(
      isPrepaid:false,prepaidDeliveryReady:false,
      professionalMode:false,
    ),isTrue);
    expect(checkoutProofSectionVisible(
      isPrepaid:true,prepaidDeliveryReady:false,
      professionalMode:false,
    ),isFalse);
    expect(checkoutProofSectionVisible(
      isPrepaid:true,prepaidDeliveryReady:true,
      professionalMode:false,
    ),isTrue);
    expect(checkoutProofSectionVisible(
      isPrepaid:false,prepaidDeliveryReady:false,
      professionalMode:true,
    ),isFalse);
  });
}
