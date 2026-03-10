package kr.co.cdd.payboard

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import kr.co.cdd.payboard.core.app.PayBoardApp

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()
        super.onCreate(savedInstanceState)
        (application as? PayBoardApplication)
            ?.appContainer
            ?.handleAuthDeepLink(intent)
        enableEdgeToEdge()
        setContent {
            PayBoardApp()
        }
    }

    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        (application as? PayBoardApplication)
            ?.appContainer
            ?.handleAuthDeepLink(intent)
    }
}
