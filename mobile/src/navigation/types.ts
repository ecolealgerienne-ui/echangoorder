import type { NavigatorScreenParams } from '@react-navigation/native';

export type PublicStackParamList = {
  Vitrine: undefined;
  Onboarding: undefined;
  AuthWelcome: undefined;
  RegisterStep1: undefined;
  RegisterStep2: undefined;
  RegisterStep3: undefined;
  Login: undefined;
  ForgotPin: undefined;
};

export type HomeStackParamList = {
  Home: undefined;
  ProductDetail: { productId: string };
};

export type CatalogStackParamList = {
  Catalog: undefined;
  CategoryProducts: { categoryId: string };
  Search: undefined;
  ProductDetail: { productId: string };
};

export type CartStackParamList = {
  Cart: undefined;
  CheckoutReceptionMode: undefined;
  CheckoutAddress: undefined;
  CheckoutOutOfZone: undefined;
  CheckoutTimeslot: undefined;
  CheckoutSummary: undefined;
  OrderConfirmation: { orderRef: string };
};

export type ProfileStackParamList = {
  Profile: undefined;
  Addresses: undefined;
  MyLocation: undefined;
  ChangePin: undefined;
  NotificationSettings: undefined;
  LanguageSettings: undefined;
  OrderHistory: undefined;
  OrderTracking: { orderRef: string };
  About: undefined;
  LegalDocument: { docType: 'cgu' | 'privacy' | 'legal' | 'cookies' };
};

export type MainTabParamList = {
  HomeTab: NavigatorScreenParams<HomeStackParamList>;
  CatalogTab: NavigatorScreenParams<CatalogStackParamList>;
  CartTab: NavigatorScreenParams<CartStackParamList>;
  ProfileTab: NavigatorScreenParams<ProfileStackParamList>;
};

export type RootStackParamList = {
  Public: NavigatorScreenParams<PublicStackParamList>;
  Main: NavigatorScreenParams<MainTabParamList>;
  Maintenance: undefined;
};

declare global {
  namespace ReactNavigation {
    interface RootParamList extends RootStackParamList {}
  }
}
