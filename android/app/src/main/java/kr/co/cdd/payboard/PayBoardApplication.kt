package kr.co.cdd.payboard

import android.app.Application
import kr.co.cdd.payboard.core.app.AppContainer
import kr.co.cdd.payboard.core.app.AppContainerOwner

class PayBoardApplication : Application(), AppContainerOwner {
    override val appContainer: AppContainer by lazy { AppContainer(this) }
}
