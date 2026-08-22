import { StatusBar } from "expo-status-bar"
import { useTranslation } from "react-i18next"
import { StyleSheet, Text, View } from "react-native"

import "./src/i18n"

export default function App() {
  const { t } = useTranslation()

  return (
    <View style={styles.container}>
      <Text style={styles.title}>{t("app.name")}</Text>
      <StatusBar style="auto" />
    </View>
  )
}

const styles = StyleSheet.create({
  container: {
    alignItems: "center",
    flex: 1,
    justifyContent: "center",
  },
  title: {
    fontSize: 24,
    fontWeight: "700",
  },
})
