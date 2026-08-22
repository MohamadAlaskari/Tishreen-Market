import { getLocales } from "expo-localization"
import i18n from "i18next"
import { initReactI18next } from "react-i18next"

import ar from "./ar.json"
import en from "./en.json"

// Arabic is primary; English is optional with Arabic fallback (docs/00 §2.6).
const deviceLanguage = getLocales()[0]?.languageCode

void i18n.use(initReactI18next).init({
  resources: {
    ar: { translation: ar },
    en: { translation: en },
  },
  lng: deviceLanguage === "en" ? "en" : "ar",
  fallbackLng: "ar",
  interpolation: {
    // React already escapes interpolated values.
    escapeValue: false,
  },
})

export default i18n
