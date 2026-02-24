// Import and register all controllers
import { application } from "controllers/application"

import DropdownController from "controllers/dropdown_controller"
import FlashController from "controllers/flash_controller"
import SecretRevealController from "controllers/secret_reveal_controller"
import ClipboardController from "controllers/clipboard_controller"
import SearchController from "controllers/search_controller"
import OtpDisplayController from "controllers/otp_display_controller"
import SecretTypeController from "controllers/secret_type_controller"
import DarkModeController from "controllers/dark_mode_controller"
import ConnectorSearchController from "controllers/connector_search_controller"
import ConnectorExecuteController from "controllers/connector_execute_controller"
import ConnectorCredentialFormController from "controllers/connector_credential_form_controller"

application.register("dropdown", DropdownController)
application.register("flash", FlashController)
application.register("secret-reveal", SecretRevealController)
application.register("clipboard", ClipboardController)
application.register("search", SearchController)
application.register("otp-display", OtpDisplayController)
application.register("secret-type", SecretTypeController)
application.register("dark-mode", DarkModeController)
application.register("connector-search", ConnectorSearchController)
application.register("connector-execute", ConnectorExecuteController)
application.register("connector-credential-form", ConnectorCredentialFormController)
