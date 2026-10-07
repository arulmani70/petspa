from openpyxl import Workbook
from openpyxl.styles import PatternFill, Font, Alignment, Border, Side
from openpyxl.utils import get_column_letter
import datetime

wb = Workbook()

# ── palette ──────────────────────────────────────────────────────────────────
BG_DARK    = "0F1923"
BG_TEAL    = "0F766E"
BG_WHITE   = "FFFFFF"
BG_GREEN   = "DCFCE7"
BG_RED     = "FEE2E2"
BG_AMBER   = "FEF3C7"
BG_ORANGE  = "FFEDD5"
BG_BLUE    = "DBEAFE"
BG_PURPLE  = "EDE9FE"
FG_DARK    = "0F1923"
FG_WHITE   = "FFFFFF"
FG_GREEN   = "166534"
FG_RED     = "991B1B"
FG_AMBER   = "78350F"
FG_ORANGE  = "7C2D12"
FG_BLUE    = "1E3A5F"

def F(hex_): return PatternFill("solid", fgColor=hex_)
def Fnt(bold=False, color=FG_DARK, size=10, italic=False):
    return Font(bold=bold, color=color, size=size, italic=italic, name="Calibri")
def A(h="left", v="center", wrap=False):
    return Alignment(horizontal=h, vertical=v, wrap_text=wrap)
def thin_border():
    s = Side(style="thin", color="D1D5DB")
    return Border(left=s, right=s, top=s, bottom=s)

def sc(c, bg=BG_WHITE, fg=FG_DARK, bold=False, size=10, h="left", wrap=False, italic=False):
    c.fill = F(bg); c.font = Fnt(bold, fg, size, italic)
    c.alignment = A(h, "center", wrap); c.border = thin_border()

# ── sheet-level header ───────────────────────────────────────────────────────
def main_header(ws, title, sub):
    ws.merge_cells("A1:I1")
    c = ws["A1"]; c.value = title
    c.fill = F(BG_DARK); c.font = Font(bold=True,color=FG_WHITE,size=15,name="Calibri")
    c.alignment = A("center","center"); ws.row_dimensions[1].height = 34
    ws.merge_cells("A2:I2")
    c2 = ws["A2"]; c2.value = sub
    c2.fill = F(BG_TEAL); c2.font = Font(color=FG_WHITE,size=9,italic=True,name="Calibri")
    c2.alignment = A("center","center"); ws.row_dimensions[2].height = 16

def col_hdr(ws, row, labels, bg=BG_DARK, fg=FG_WHITE):
    for ci, lbl in enumerate(labels, 1):
        c = ws.cell(row, ci); c.value = lbl
        c.fill=F(bg); c.font=Font(bold=True,color=fg,size=10,name="Calibri")
        c.alignment=A("center","center",True); c.border=thin_border()
    ws.row_dimensions[row].height = 30

def wrow(ws, row, vals, row_bg=BG_WHITE, bold_set=None, wrap_set=None, h="left", rh=None):
    bold_set = bold_set or set()
    wrap_set = wrap_set or set()
    for ci, v in enumerate(vals, 1):
        c = ws.cell(row, ci); c.value = v
        b = ci in bold_set; w = ci in wrap_set
        sc(c, row_bg, FG_DARK, b, 10, h, w)
    if rh: ws.row_dimensions[row].height = rh

def widths(ws, wlist):
    for i, w in enumerate(wlist, 1):
        ws.column_dimensions[get_column_letter(i)].width = w

STATUS_COLOR = {
    "COMPLETE":     (BG_GREEN,  FG_GREEN),
    "PENDING":      (BG_RED,    FG_RED),
    "PARTIAL":      (BG_AMBER,  FG_AMBER),
    "BROKEN":       (BG_RED,    FG_RED),
    "NOT IMPL":     (BG_RED,    FG_RED),
    "IN PROGRESS":  (BG_AMBER,  FG_AMBER),
    "CRITICAL":     (BG_RED,    FG_RED),
    "HIGH":         (BG_ORANGE, FG_ORANGE),
    "MEDIUM":       (BG_AMBER,  FG_AMBER),
    "LOW":          (BG_BLUE,   FG_BLUE),
    "DONE":         (BG_GREEN,  FG_GREEN),
    "NO ACTION":    (BG_GREEN,  FG_GREEN),
}

def paint_status(ws, row, col, val):
    bg, fg = BG_WHITE, FG_DARK
    for k, (b, f) in STATUS_COLOR.items():
        if k in str(val).upper():
            bg, fg = b, f; break
    c = ws.cell(row, col)
    c.fill = F(bg); c.font = Font(bold=True, color=fg, size=10, name="Calibri")
    c.alignment = A("center","center"); c.border = thin_border()

# ════════════════════════════════════════════════════════════════════════════
# SHEET 1 — SUMMARY DASHBOARD
# ════════════════════════════════════════════════════════════════════════════
ws1 = wb.active
ws1.title = "Summary Dashboard"
main_header(ws1,
    "SHEAR HEAVEN PET SPA — Project Status Report",
    f"Audit Date: {datetime.date.today().strftime('%d %B %Y')}  |  Flutter/Dart  |  API: https://shear-heaven-api.genzcodershub.com")

# ── scorecards row ───────────────────────────────────────────────────────────
r = 4
labels  = ["COMPLETE", "IN PROGRESS / PARTIAL", "PENDING / NOT DONE", "CRITICAL BUGS", "HIGH PRIORITY FIXES", "MEDIUM PRIORITY FIXES"]
values  = ["18 APIs",  "2 features",             "6 APIs + 4 features", "5",             "7",                    "8"]
bgs     = [BG_GREEN,   BG_AMBER,                  BG_RED,               BG_RED,           BG_ORANGE,              BG_AMBER]
fgs     = [FG_GREEN,   FG_AMBER,                  FG_RED,               FG_RED,           FG_ORANGE,              FG_AMBER]
# Merge pairs: A4:B4  C4:D4  etc.
pairs = [(1,2),(3,4),(5,6),(7,8),(9,10),(11,12)]
for (s,e), lbl, val, bg, fg in zip(pairs, labels, values, bgs, fgs):
    ws1.merge_cells(start_row=r, start_column=s, end_row=r, end_column=e)
    c = ws1.cell(r, s); c.value = lbl
    c.fill = F(BG_DARK); c.font = Font(bold=True,color=FG_WHITE,size=9,name="Calibri")
    c.alignment = A("center","center"); ws1.row_dimensions[r].height = 20
    ws1.merge_cells(start_row=r+1, start_column=s, end_row=r+1, end_column=e)
    c2 = ws1.cell(r+1, s); c2.value = val
    c2.fill = F(bg); c2.font = Font(bold=True,color=fg,size=18,name="Calibri")
    c2.alignment = A("center","center"); ws1.row_dimensions[r+1].height = 32

r = 7
# ── module status table ──────────────────────────────────────────────────────
ws1.merge_cells(f"A{r}:L{r}")
hc = ws1.cell(r,1); hc.value = "MODULE-BY-MODULE STATUS"
hc.fill=F(BG_TEAL); hc.font=Font(bold=True,color=FG_WHITE,size=11,name="Calibri")
hc.alignment=A("center","center"); ws1.row_dimensions[r].height=22
r += 1

col_hdr(ws1, r, ["Module","What is COMPLETE","What is PENDING / BROKEN","Overall Status"])
r += 1

modules = [
    ("AUTH",
     "Signup · Login · Send OTP · Verify OTP · Logout · Refresh Token (auto-interceptor) · Tokens in SecureStorage",
     "Forgot Password (page exists but is non-functional — no email field, no API call)\nReset Password (throws UnimplementedError at runtime)",
     "PARTIAL"),
    ("PETS",
     "Get All Pets (API) · Create Pet (multipart API) · Update Pet (multipart API) · Delete Pet (API) · Photo upload · DOB/gender/vaccination fields",
     "None — all CRUD is realtime API",
     "COMPLETE"),
    ("SERVICES / PACKAGES",
     "Load breeds, packages, add-ons, walk-in services from /api/service-packages · Display in BookingServicePage, ServicesPage, HomePage",
     "Breed service IDs stored as string ('breed_X_grooming') — int.tryParse returns null downstream\nPrices stored as '$45' strings → estimatedTotal always shows $0.00",
     "PARTIAL"),
    ("STORE INFO",
     "Groomers loaded (API) · Pet weights loaded (API) · Holidays loaded (API) · Service hours loaded (API)",
     "clientId/regionId/storeId never populated from login → all store API headers use hardcoded fallbacks\nService-hours field key assumption ('HolidayList') may be wrong",
     "PARTIAL"),
    ("GROOMER AVAILABILITY",
     "GET /api/groomer-availability integrated · Store closed/holiday handling · Per-groomer slot filtering · 'No preference' union slots · Slot staleness validation · Unavailable groomer UI",
     "ClientID casing inconsistency vs ClientId in other calls\nclientId/regionId/storeId hardcoded fallback",
     "PARTIAL"),
    ("BOOKING AVAILABILITY",
     "POST /api/availability integrated (Step 1) · totalDurationMinutes from API · totalPrice from API · Re-validation before booking · endTime correction from backend",
     "clientId/regionId/storeId hardcoded fallback\nStep 1 failure is silent (falls back to 60min with no user notice)",
     "PARTIAL"),
    ("CREATE BOOKING",
     "POST /api/bookings integrated · startTime from backend slot · endTime from backend slot · Re-validate before create · GROOMER_NOT_AVAILABLE handled · Duplicate submission guard · draft.reset() after success",
     "clientId/regionId/storeId hardcoded fallback\ngroomerId=0 sent for 'No Preference' (backend may expect null or omit)\nDuplicate serviceId+packageId for package bookings",
     "PARTIAL"),
    ("BOOKING HISTORY",
     "Page exists · Tabs (Upcoming/Past/Cancelled) · Loading spinner · Empty state text · Per-booking pet enrichment call",
     "BROKEN: getAllBookings/getUpcomingBookings/getPastBookings all query SQLite (which is NEVER written)\nAll tabs always show 0 items\nGET /api/bookings not implemented\nBooking date displays hardcoded 'Aug 4, 2026' fallback\nStatus chip case-mismatch",
     "BROKEN"),
    ("PROFILE",
     "Page exists · Name and email pre-filled from session",
     "Phone hardcoded to '+(817) 123-4567'\nSave Changes is a no-op (no API call)\nPUT /api/profile not implemented",
     "PENDING"),
    ("MY PETS PAGE",
     "Pet list from API · Create/Edit/Delete via API · Photo display",
     "No delete confirmation dialog",
     "COMPLETE"),
    ("HOME PAGE",
     "Pets loaded · Services/Packages from API · Pull-to-refresh · Logout dialog",
     "Location hardcoded 'California'\nPackage price fallbacks hardcoded $68/$40",
     "PARTIAL"),
    ("NAVIGATION",
     "GoRouter with 24 named routes · Booking flow push/pop correct · Draft reset after booking",
     "Draft NOT reset when user enters booking flow from home (stale data risk if user abandoned a previous booking)\n'View' on BookingConfirmedPage goes to broken MyBookingsPage",
     "PARTIAL"),
    ("ERROR HANDLING",
     "401 auto-refresh with retry · GROOMER_NOT_AVAILABLE handled · Service load retry button · Groomer availability retry · Duplicate submission guard",
     "401 session clear does NOT redirect to login\n404/403/500 not distinguished — all show generic message\nForgot Password has zero error handling",
     "PARTIAL"),
    ("CODE QUALITY",
     "10 flutter analyze issues (all info-level, none blocking) · No compile errors",
     "10 info warnings to address (unnecessary braces, curly_braces_in_flow_control, etc.)\nTypo: 'constansts.dart' filename\n35+ Python dev scripts in project root (add_route.py, fix1.py, etc.) should be removed",
     "PARTIAL"),
]

for mod, done, pending, status in modules:
    row_bg = BG_GREEN if status=="COMPLETE" else (BG_RED if status=="BROKEN" else BG_AMBER if status=="PARTIAL" else BG_RED)
    for ci, val in enumerate([mod, done, pending, status], 1):
        c = ws1.cell(r, ci); c.value = val
        if ci == 1:
            sc(c, BG_DARK, FG_WHITE, True, 10, "left", False)
        elif ci == 4:
            paint_status(ws1, r, ci, val)
        else:
            sc(c, row_bg, FG_DARK, False, 10, "left", True)
    ws1.row_dimensions[r].height = 56
    r += 1

widths(ws1, [22, 65, 70, 16])

# ════════════════════════════════════════════════════════════════════════════
# SHEET 2 — API ENDPOINTS (Complete vs Pending)
# ════════════════════════════════════════════════════════════════════════════
ws2 = wb.create_sheet("API Endpoints")
main_header(ws2, "ALL API ENDPOINTS — Complete vs Pending",
    "24 endpoints identified across Auth · Pets · Store · Services · Bookings")

r = 3
col_hdr(ws2, r, ["#","Method","Endpoint","Module","Status",
                  "Repository Method","Called From","Key Payload Fields","Key Response Fields","Issues / Notes"])
r += 1

apis = [
  # (num, method, endpoint, module, status, repo, caller, payload, response, notes)
  (1,"POST","/api/auth/signup","Auth","COMPLETE",
   "AuthRepository.register()","AuthBloc._onRegisterSubmitted",
   "name, email, mobile, password, confirmPassword, clientId, regionId, storeId",
   "success, message, errors[]",
   "confirmPassword always = password (no separate confirm field). clientId/regionId/storeId always empty string at signup time."),
  (2,"POST","/api/auth/send-otp","Auth","COMPLETE",
   "AuthRepository.sendOtp()","AuthBloc._onSendOtpSubmitted / _onRegisterSubmitted",
   "email, clientId, regionId, storeId",
   "success, message",
   "Called twice during registration. Log says 'Demo OTP' — misleading."),
  (3,"POST","/api/auth/verify-otp","Auth","COMPLETE",
   "AuthRepository.verifyOtp()","AuthBloc._onVerifyOtpSubmitted",
   "email (from pendingEmail), otp",
   "success, data.accessToken, data.refreshToken, data.user",
   "user = data['user'] ?? data fallback may store entire data object if 'user' key absent."),
  (4,"POST","/api/auth/login","Auth","COMPLETE",
   "AuthRepository.login()","AuthBloc._onLoginSubmitted",
   "email, password",
   "success, data.accessToken, data.refreshToken, data.user",
   "CRITICAL: clientId/regionId/storeId never extracted from login response."),
  (5,"POST","/api/auth/logout","Auth","COMPLETE",
   "AuthRepository.logout()","AuthBloc._onLogoutSubmitted",
   "refreshToken",
   "—",
   "Session cleared even if API fails. Correct."),
  (6,"POST","/api/auth/refresh-token","Auth","COMPLETE",
   "ApiRepository interceptor (auto on 401)","Automatic — no BLoC",
   "refreshToken",
   "data.accessToken, data.refreshToken",
   "Uses separate Dio instance to avoid loop. On failure: clearSession() called but NO redirect to login screen."),
  (7,"POST","/api/auth/forgot-password","Auth","PENDING",
   "NOT IMPLEMENTED","ForgotPasswordPage (broken — just navigates to login)",
   "email (not wired up)",
   "—",
   "Page has no email field. Button only calls context.goNamed(login). Must be completely rebuilt."),
  (8,"POST","/api/auth/reset-password","Auth","PENDING",
   "AuthRepository.resetPassword() → throws UnimplementedError","AuthBloc._onResetPasswordSubmitted (will crash)",
   "email, code, newPassword",
   "—",
   "Will crash at runtime with UnimplementedError. Remove handler or implement endpoint."),
  (9,"GET","/api/pets","Pets","COMPLETE",
   "PetRepository.getAllPets()","PetBloc.InitializePets / GetAllPets",
   "Bearer token (header only)",
   "data.pets[] → id, petName, breed, weight, age, gender, dateOfBirth, notesAllergies, profilePictureUrl, allVaccinatedCurrent, lastVaccinatedDate, behaviorNotes",
   "Response mapped via _mapFromApi() to DB constant keys for UI compatibility."),
  (10,"GET","/api/pets/:id","Pets","PARTIAL",
   "PetRepository.getPetById()","MyBookingsPage enrichment loop (no BLoC)",
   "Path param: id",
   "Assumed flat response — if API wraps in data.pet, extraction fails",
   "Called in N+1 loop per booking row. Response structure assumption may be wrong."),
  (11,"POST","/api/pets","Pets","COMPLETE",
   "PetRepository.createPet()","PetBloc.CreatePet",
   "multipart: petName, breed, weight, age, dateOfBirth, gender, notesAllergies, allVaccinatedCurrent, lastVaccinatedDate, behaviorNotes + file: profilePicture",
   "success, id/_id",
   "allVaccinatedCurrent sent as string 'true'/'false' not boolean. Photo is required."),
  (12,"PUT","/api/pets/:id","Pets","COMPLETE",
   "PetRepository.updatePet()","PetBloc.UpdatePet",
   "Same as create; path param: id. Existing network photo URLs skipped.",
   "bool success",
   "Edit mode detected via GoRouter extra. Correct."),
  (13,"DELETE","/api/pets/:id","Pets","COMPLETE",
   "PetRepository.deletePet()","PetBloc.DeletePet",
   "Path param: id",
   "bool success",
   "No delete confirmation dialog in UI before calling this."),
  (14,"GET","/api/groomers","Store","COMPLETE",
   "StoreRepository.getGroomers()","App startup (StoreRepository.initialize)",
   "x-client-id, x-region-id, x-store-id headers",
   "data.Groomers[]",
   "Loaded at startup. Not used directly in booking UI (groomer-availability provides groomers instead)."),
  (15,"GET","/api/service-hours","Store","PARTIAL",
   "StoreRepository.getStoreSchedule()","App startup",
   "Headers only",
   "data.HolidayList[] ← ASSUMED key name for service-hours endpoint",
   "Field key assumption risk. Data not used in booking availability flow (redundant vs groomer-availability response)."),
  (16,"GET","/api/pet-weights","Store","COMPLETE",
   "StoreRepository.getPetWeights()","CreatePetPage._loadWeights()",
   "Headers only",
   "data.petWeights[].label",
   "Falls back to ['Small','Medium','Large'] if empty. No error shown on failure."),
  (17,"GET","/api/holidays","Store","COMPLETE",
   "StoreRepository._loadHolidays()","App startup",
   "Headers only",
   "data.HolidayList[].Date (MM/DD/YYYY format)",
   "Date format assumed MM/DD/YYYY. No refresh during session."),
  (18,"GET","/api/service-packages","Services","COMPLETE",
   "ServiceRepository.getBookingServices()","ServiceBloc.InitializeServices",
   "x-client-id, x-region-id, x-store-id headers",
   "data.Breeds[], data.Packages[], data.AddOns[], data['Walk In Services'][]",
   "Breed service IDs fall back to 'breed_X_grooming' strings when ServiceId key missing → int.tryParse returns null."),
  (19,"GET","/api/groomer-availability","Bookings","COMPLETE",
   "BookingRepository.getGroomerAvailability()","BookingDateTimePage._loadAvailability() Step 2",
   "date, ClientID (⚠ capital D), RegionId, StoreId, durationMinutes, groomerId?",
   "data.store.closed, data.store.holiday, data.groomers[].availableSlots[], data.groomers[].available, data.groomers[].reason",
   "ClientID vs ClientId casing inconsistency. clientId/regionId/storeId always hardcoded fallback."),
  (20,"POST","/api/availability","Bookings","COMPLETE",
   "BookingRepository.getAvailability()","BookingDateTimePage (Step 1) + BookingReviewPage (re-validate)",
   "ClientId, RegionId, StoreId, date, serviceId?, packageId?, addOnIds[]?, groomerId?",
   "success, data.totalDurationMinutes, data.totalPrice, data.availableSlots[]",
   "clientId/storeId/regionId hardcoded. Step 1 failure is silent (60min fallback with no user notice)."),
  (21,"POST","/api/bookings","Bookings","COMPLETE",
   "BookingRepository.createBookingApi()","BookingReviewPage._confirmBooking()",
   "ClientId, RegionId, StoreId, petId, serviceId?, packageId?, addOnIds[], groomerId, bookingDate, startTime, endTime",
   "success, data.bookingId, data.status, data.totalPrice, data.totalDurationMinutes",
   "clientId/regionId/storeId hardcoded. groomerId=0 for 'No Preference'. GROOMER_NOT_AVAILABLE handled correctly."),
  (22,"GET","/api/bookings","Bookings","PENDING",
   "NOT IMPLEMENTED — getAllBookings/getUpcomingBookings/getPastBookings use SQLite instead","MyBookingsPage",
   "status filter, pagination",
   "—",
   "CRITICAL: SQLite TABLE_BOOKINGS is NEVER written. My Bookings always shows 0 items. Must implement this API."),
  (23,"GET","/api/bookings/:id","Bookings","PENDING",
   "NOT IMPLEMENTED","—",
   "Path param: id",
   "—",
   "No booking detail screen exists. Needed when My Bookings is fixed."),
  (24,"PATCH","/api/bookings/:id/cancel","Bookings","PENDING",
   "NOT IMPLEMENTED","—",
   "Path param: id",
   "—",
   "No cancel button exists in UI. Must be added alongside My Bookings fix."),
]

method_color = {"GET":BG_BLUE,"POST":BG_GREEN,"PUT":BG_AMBER,"PATCH":BG_PURPLE,"DELETE":BG_RED}

for row_data in apis:
    num, method, endpoint, module, status, repo, caller, payload, response, notes = row_data
    row_bg = BG_GREEN if status=="COMPLETE" else (BG_RED if status in ("PENDING","BROKEN") else BG_AMBER)
    vals = [num, method, endpoint, module, status, repo, caller, payload, response, notes]
    for ci, v in enumerate(vals, 1):
        c = ws2.cell(r, ci); c.value = v
        if ci == 1:
            sc(c, BG_DARK, FG_WHITE, True, 10, "center")
        elif ci == 2:
            mbg = method_color.get(method, BG_WHITE)
            sc(c, mbg, FG_DARK, True, 10, "center")
        elif ci == 5:
            paint_status(ws2, r, ci, status)
        else:
            wrap = ci in {6,7,8,9,10}
            sc(c, row_bg, FG_DARK, False, 10, "left", wrap)
    ws2.row_dimensions[r].height = 44
    r += 1

widths(ws2, [4, 8, 34, 12, 14, 36, 32, 48, 42, 58])

# ════════════════════════════════════════════════════════════════════════════
# SHEET 3 — COMPLETE FEATURES (Green)
# ════════════════════════════════════════════════════════════════════════════
ws3 = wb.create_sheet("✅ Completed")
main_header(ws3, "COMPLETED FEATURES",
    "Everything that is fully implemented and working via realtime API")

r = 3
col_hdr(ws3, r, ["#","Feature / API","Module","Details","File / Method"])
r += 1

completed = [
  (1,"User Registration (Signup)","Auth","POST /api/auth/signup → OTP → Verify flow. Name, email, mobile, password sent. Pending email stored for OTP verification.","auth_repository.dart → register()"),
  (2,"Send OTP","Auth","POST /api/auth/send-otp. Email stored in SharedPreferences as pendingEmail.","auth_repository.dart → sendOtp()"),
  (3,"Verify OTP","Auth","POST /api/auth/verify-otp. accessToken + refreshToken saved to FlutterSecureStorage. User session saved to SharedPreferences.","auth_repository.dart → verifyOtp()"),
  (4,"Login","Auth","POST /api/auth/login. JWT tokens saved securely. BLoC emits authenticated state and navigates home.","auth_repository.dart → login()"),
  (5,"Logout","Auth","POST /api/auth/logout (invalidates refresh token on server). Session cleared locally even on API failure.","auth_repository.dart → logout()"),
  (6,"Auto Token Refresh (401 interceptor)","Auth","Dio interceptor catches 401 → POST /api/auth/refresh-token → saves new tokens → retries original request. Uses separate Dio instance to avoid loop.","api_repository.dart → interceptor"),
  (7,"Get All Pets","Pets","GET /api/pets → maps via _mapFromApi() to DB constant keys. Loaded into PetBloc for PetSelectPage and MyPetsPage.","pet_repository.dart → getAllPets()"),
  (8,"Create Pet","Pets","POST /api/pets as multipart/form-data. Fields: petName, breed, weight, age, dateOfBirth, gender, notesAllergies, allVaccinatedCurrent, lastVaccinatedDate, behaviorNotes. File: profilePicture.","pet_repository.dart → createPet()"),
  (9,"Update Pet","Pets","PUT /api/pets/:id multipart. Existing network photo URLs correctly skipped. Edit mode passed via GoRouter extra.","pet_repository.dart → updatePet()"),
  (10,"Delete Pet","Pets","DELETE /api/pets/:id. PetBloc refreshes list after deletion.","pet_repository.dart → deletePet()"),
  (11,"Load Service Packages","Services","GET /api/service-packages. Parses Breeds, Packages, AddOns, Walk In Services into typed lists for ServiceBloc.","service_repository.dart → getBookingServices()"),
  (12,"Display Services / Packages","Services","ServiceBloc drives BookingServicePage, ServicesPage, PackagesPage, HomePage grid. Loading/empty/error states all handled.","service_bloc.dart + booking_service_page_mobile.dart"),
  (13,"Load Groomers","Store","GET /api/groomers at app startup. Stored in StoreRepository memory.","store_repository.dart → getGroomers()"),
  (14,"Load Pet Weights","Store","GET /api/pet-weights. Populates weight dropdown in CreatePetPage dynamically from API.","store_repository.dart → getPetWeights()"),
  (15,"Load Holidays","Store","GET /api/holidays at startup. isHoliday() helper used by SharedCalendar to disable holiday dates.","store_repository.dart → _loadHolidays()"),
  (16,"Load Service Hours","Store","GET /api/service-hours at startup. Stored in memory.","store_repository.dart → getStoreSchedule()"),
  (17,"Booking Step 1 — Get Duration & Price","Bookings","POST /api/availability → extracts totalDurationMinutes and totalPrice → stores in BookingDraft. Used to drive Step 2 groomer-availability call with correct duration.","booking_date_time_page_mobile.dart → _loadAvailability()"),
  (18,"Booking Step 2 — Groomer Availability","Bookings","GET /api/groomer-availability with real duration from Step 1. Returns per-groomer available slots, store closed/holiday flags, unavailable reasons.","booking_repository.dart → getGroomerAvailability()"),
  (19,"Slot Selection from Backend","Bookings","startTime and endTime stored from backend availableSlots[n] via setSelectedSlot(). No local time calculation.","booking_draft.dart → setSelectedSlot()"),
  (20,"Store Closed / Holiday UI","Bookings","data.store.closed and data.store.holiday parsed from groomer-availability response. Banners shown, Continue blocked.","booking_date_time_page_mobile.dart"),
  (21,"Groomer Chip UI","Bookings","Groomer list from groomer-availability response. Unavailable groomers shown greyed with reason. Tap changes groomer filter and reloads slots.","booking_date_time_page_mobile.dart → _onGroomerSelected()"),
  (22,"Slot Staleness Validation","Bookings","_validateSelectedSlot() called after reload. Clears selected slot if no longer in availableSlots. Also clears on date/groomer change.","booking_date_time_page_mobile.dart"),
  (23,"Booking Review Screen","Bookings","Displays pet, service, date/time, groomer from BookingDraft. No API call on this screen. Edit links back to each step.","booking_review_page_mobile.dart"),
  (24,"Pre-flight Slot Re-validation","Bookings","POST /api/availability called again before creating booking. Checks selected slot still in availableSlots by startTime+endTime match. Corrects endTime from backend if changed.","booking_review_page_mobile.dart → _confirmBooking()"),
  (25,"Create Booking (API)","Bookings","POST /api/bookings with complete payload. draft.lastBooking snapshot saved, draft.reset() clears state, navigates to BookingConfirmedPage.","booking_repository.dart → createBookingApi()"),
  (26,"GROOMER_NOT_AVAILABLE handling","Bookings","If server returns code: 'GROOMER_NOT_AVAILABLE', user sees snackbar and navigates back to date/time page.","booking_review_page_mobile.dart"),
  (27,"Duplicate Submission Prevention","Bookings","_confirming flag set on first tap; Confirm button shows spinner; prevents double API call.","booking_review_page_mobile.dart"),
  (28,"Booking Confirmed Screen","Bookings","Displays bookingId, pet, service, date, time, duration, price from API response (draft.lastBooking snapshot).","booking_confirmed_page_mobile.dart"),
  (29,"Pull-to-Refresh on Home","Home","RefreshIndicator wraps ListView. Refreshes user name + service data.","home_page_mobile.dart"),
  (30,"Network Status Widget","Common","NetworkService monitors connectivity. NetworkStatusWidget shows offline banner.","network_service.dart + network_status_widget.dart"),
  (31,"Session Persistence","Auth","AccessToken + RefreshToken in FlutterSecureStorage. User data in SharedPreferences. clientId/regionId/storeId in SharedPreferences (when set).","session_service.dart"),
]

for num, feat, mod, detail, file_ in completed:
    for ci, v in enumerate([num, feat, mod, detail, file_], 1):
        c = ws3.cell(r, ci); c.value = v
        if ci == 1:   sc(c, BG_DARK, FG_WHITE, True, 10, "center")
        elif ci == 2: sc(c, BG_GREEN, FG_GREEN, True, 10, "left")
        elif ci == 3: sc(c, BG_GREEN, FG_GREEN, False, 10, "center")
        else:         sc(c, BG_GREEN, FG_DARK, False, 10, "left", ci in {4,5})
    ws3.row_dimensions[r].height = 36
    r += 1

widths(ws3, [4, 35, 14, 70, 45])

# ════════════════════════════════════════════════════════════════════════════
# SHEET 4 — PENDING / BROKEN
# ════════════════════════════════════════════════════════════════════════════
ws4 = wb.create_sheet("❌ Pending & Broken")
main_header(ws4, "PENDING, BROKEN & PARTIALLY DONE",
    "Everything that needs to be built, fixed, or completed before the app is production-ready")

r = 3
col_hdr(ws4, r, ["#","Feature / Bug","Module","Status","What Exists Now",
                  "What Needs to Be Done","Priority","File to Change"])
r += 1

pending = [
  # (num, feature, module, status, current_state, what_to_do, priority, file)
  (1,"My Bookings — always empty","Bookings","BROKEN",
   "getUpcomingBookings/getPastBookings/getAllBookings query SQLite TABLE_BOOKINGS which is NEVER written. All tabs show 0 items always.",
   "Implement GET /api/bookings. Add BookingRepository.getBookingsFromApi(). Update MyBookingsPage to use API. Update _BookingCard to read API response fields (bookingDate, startTime, endTime, status, totalPrice).",
   "CRITICAL","booking_repository.dart + my_bookings_page_mobile.dart"),
  (2,"clientId / regionId / storeId never set","Auth / Bookings","CRITICAL",
   "saveClientId/saveRegionId/saveStoreId methods exist in SessionService but are NEVER called anywhere in production code. All API calls fall back to hardcoded 'SHEAR-001' / 'DWG-001'.",
   "Extract clientId, regionId, storeId from login response (data object). Call session.saveClientId(), saveRegionId(), saveStoreId() in AuthRepository.login() AND AuthRepository.verifyOtp().",
   "CRITICAL","auth_repository.dart"),
  (3,"Forgot Password — non-functional","Auth","BROKEN",
   "Page only has two password fields and a button that calls context.goNamed(login). No email input. No API call. No OTP flow.",
   "Rebuild: Step 1 — email input + POST /api/auth/send-otp. Step 2 — OTP input (reuse OtpPage). Step 3 — new password fields + POST /api/auth/reset-password.",
   "CRITICAL","forgot_password_page_mobile.dart + auth_repository.dart"),
  (4,"Reset Password throws UnimplementedError","Auth","BROKEN",
   "AuthRepository.resetPassword() throws UnimplementedError. AuthBloc has the handler. If called, app crashes.",
   "Implement POST /api/auth/reset-password endpoint call in AuthRepository.",
   "CRITICAL","auth_repository.dart"),
  (5,"401 → no redirect to login","Auth","BROKEN",
   "When token refresh fails, interceptor calls clearSession() but the user stays on their current screen with cleared credentials. Any subsequent API call will fail silently.",
   "After clearSession() in ApiRepository interceptor, dispatch a navigation event or use a GlobalKey<NavigatorState> to push to login screen.",
   "HIGH","api_repository.dart"),
  (6,"estimatedTotal always $0.00","Services / Booking","BROKEN",
   "BookingDraft.estimatedTotal does 'servicePrice is num' check. Breed/walkin service prices are stored as '\$45' strings from ServiceRepository → check always fails → returns 0.",
   "Fix ServiceRepository to store prices as double (strip '$' and parse). Then estimatedTotal will work. Alternatively, prefer apiTotalPrice (from API) over estimatedTotal on the bottom bar.",
   "HIGH","service_repository.dart + booking_service_page_mobile.dart"),
  (7,"Breed service IDs are strings, not ints","Services / Booking","BROKEN",
   "When ServiceId key is missing from API, ID falls back to 'breed_{breedId}_grooming' string. extractServiceIds() → int.tryParse returns null → serviceId omitted from availability/booking payload.",
   "Store breed service IDs as ints. Use ServiceId/serviceId/id int value. If missing, make a second GET call or use BreedTypeId as fallback int. Do NOT use string IDs for anything the backend expects as int.",
   "HIGH","service_repository.dart + booking_draft.dart"),
  (8,"Profile page — Save Changes does nothing","Account","PENDING",
   "ProfilePageMobile has form fields. 'Save Changes' button only calls context.pop(). No PUT /api/profile call. Phone hardcoded '+(817) 123-4567'.",
   "Implement PUT /api/profile. Load all profile fields from session (or GET /api/profile). Remove hardcoded phone. Validate fields before save.",
   "HIGH","profile_page_mobile.dart + auth_repository.dart (add updateProfile)"),
  (9,"Booking status chip case-mismatch","Bookings","BROKEN",
   "_statusChip checks status == 'CONFIRMED' after .toUpperCase(). But SQLite COLUMN_STATUS defaults to 'PENDING'. Once API is added, API returns 'confirmed'/'pending' (lowercase) — .toUpperCase() fixes it, but 'PENDING' status would show as 'Cancelled' (red) due to else branch.",
   "After implementing GET /api/bookings: add explicit 'PENDING' case to _statusChip. Map API status values ('confirmed','pending','cancelled','completed') correctly to display labels and colors.",
   "HIGH","my_bookings_page_mobile.dart → _statusChip()"),
  (10,"Booking date shows 'Aug 4, 2026' hardcoded","Bookings","BROKEN",
   "_dateLabel() parses slot column as 'date|time' format. slot is always '' from SQLite. Falls back to hardcoded 'Aug 4, 2026'.",
   "Replace slot parsing with actual bookingDate + startTime fields from GET /api/bookings response.",
   "HIGH","my_bookings_page_mobile.dart → _dateLabel()"),
  (11,"Cancel Booking — not implemented","Bookings","PENDING",
   "No cancel button in UI. cancelBooking() in BookingRepository uses SQLite updateBookingStatus().",
   "Add cancel button to _BookingCard. Implement PATCH/DELETE /api/bookings/:id/cancel in BookingRepository. Show confirmation dialog before cancelling.",
   "MEDIUM","booking_repository.dart + my_bookings_page_mobile.dart"),
  (12,"GET /api/bookings/:id — not implemented","Bookings","PENDING",
   "No method in BookingRepository. No booking detail screen.",
   "Implement when booking detail page is added. Low urgency until My Bookings list works.",
   "LOW","booking_repository.dart"),
  (13,"ClientID casing inconsistency","Bookings","MEDIUM",
   "getGroomerAvailability sends 'ClientID' (capital D) in query params. getAvailability sends 'ClientId'. Inconsistent.",
   "Standardize to 'ClientId' in both places (match the POST /api/availability payload convention).",
   "MEDIUM","booking_repository.dart → getGroomerAvailability()"),
  (14,"Duplicate serviceId + packageId in package booking","Bookings","MEDIUM",
   "For packages: effectiveServiceId = packageId, so payload gets serviceId: packageId AND packageId: packageId.",
   "When packageId is set, omit 'serviceId' from payload entirely OR set it only to the actual serviceId (not packageId).",
   "MEDIUM","booking_review_page_mobile.dart + booking_repository.dart → getAvailability()"),
  (15,"Step 1 failure silent (60min fallback)","Bookings","MEDIUM",
   "When POST /api/availability fails, durationMinutes falls back to 60 with no user notification.",
   "Add warning log and show a subtle notice to user: 'Could not calculate exact duration. Using estimated duration.'",
   "MEDIUM","booking_date_time_page_mobile.dart → _loadAvailability()"),
  (16,"getPetById response structure assumption","Pets","MEDIUM",
   "getPetById passes full API response directly to _mapFromApi(). If API wraps in data.pet, mapping fails silently.",
   "Verify /api/pets/:id response shape. Add data?['pet'] ?? data extraction like getAllPets does with data['pets'].",
   "MEDIUM","pet_repository.dart → getPetById()"),
  (17,"Hardcoded fallback prices $68 / $40","Home / Packages","LOW",
   "Homepage and PackagesPage show '$68' and '$40' as package price fallbacks when grooming_price/bath_price keys absent.",
   "Remove hardcoded fallbacks. Show API price field or 'Contact for pricing' if price is unavailable.",
   "LOW","home_page_mobile.dart + packages_page_mobile.dart"),
  (18,"'California' hardcoded location","Home","LOW",
   "User location in header is always 'California' — not from session or API.",
   "Read location from session user data if available, else omit or show 'Arlington, TX' as the store's fixed location.",
   "LOW","home_page_mobile.dart"),
  (19,"'Add to Calendar' button not implemented","Bookings","LOW",
   "onTap: () {} — button does nothing.",
   "Implement using add_2_calendar or url_launcher to open device calendar with booking details.",
   "LOW","booking_confirmed_page_mobile.dart"),
  (20,"Delete pet — no confirmation dialog","Pets","LOW",
   "Delete is triggered directly. No 'Are you sure?' dialog.",
   "Add AlertDialog confirmation before dispatching DeletePet event.",
   "LOW","my_pets_page_mobile.dart"),
  (21,"'Demo OTP' misleading log","Auth","LOW",
   "AuthBloc logs 'Demo OTP: $otp' but sendOtp returns string 'sent', not an OTP code.",
   "Remove or change to: _log.d('OTP send result: $otp')",
   "LOW","auth_bloc.dart"),
  (22,"No redirect to login after session clear","Auth","HIGH",
   "clearSession() in interceptor leaves user on broken screen with empty credentials.",
   "After clearSession(), navigate to login via GoRouter. Use a stream/event bus or GlobalKey<NavigatorState>.",
   "HIGH","api_repository.dart → interceptor onError"),
  (23,"Log missing: API response bodies","Common","MEDIUM",
   "ApiRepository.get/post only logs path, not query params or response bodies. Hard to debug availability/booking issues.",
   "Add response summary logging. Add query params to GET log. Keep POST payload log sanitized (no tokens/passwords).",
   "MEDIUM","api_repository.dart"),
  (24,"Flutter analyze — 10 info warnings","Code Quality","LOW",
   "10 info-level warnings: use_null_aware_elements, unnecessary_brace_in_string_interps, curly_braces_in_flow_control_structures, unnecessary_underscores.",
   "Fix all 10. None are blocking but indicate code quality debt.",
   "LOW","booking_repository.dart, booking_review_page_mobile.dart, booking_confirmed_page_mobile.dart, home_page_mobile.dart, create_pet_page_mobile.dart, shared_calendar.dart"),
  (25,"Remove SQLite dead code after API migration","Code Quality","MEDIUM",
   "createBooking(), updateBookingStatus(), getBookedSlotsForDate(), getBookingsForDate(), getBookingById() all dead relative to API flow.",
   "After GET /api/bookings is implemented, remove these SQLite methods. Consider removing DatabaseRepository entirely.",
   "MEDIUM","booking_repository.dart + database_repository.dart"),
  (26,"35+ Python dev scripts in project root","Code Quality","LOW",
   "add_route.py, fix1.py, fix2.py, check.py, check2.py ... etc. pollute the project root.",
   "Move to a /scripts or /tools folder or add to .gitignore.",
   "LOW","project root"),
  (27,"ServiceRepository.getStoreSchedule() field key assumption","Store","MEDIUM",
   "Parses data['HolidayList'] from /api/service-hours endpoint. If key is 'ServiceHours' or 'Schedule', always returns empty list.",
   "Verify actual response shape of /api/service-hours and fix the key name.",
   "MEDIUM","store_repository.dart → getStoreSchedule()"),
  (28,"Booking draft not reset on booking flow entry","Bookings","MEDIUM",
   "BookingDraft is only reset after successful booking. If user abandons a booking and starts again from Home, stale pet/service/date/slot may be pre-selected.",
   "Call ServicesLocator.bookingDraft.reset() when user enters booking flow (PetSelectPage.initState or when 'Book Now' is tapped).",
   "MEDIUM","pet_select_page_mobile.dart or home_page_mobile.dart"),
]

for row_data in pending:
    num, feat, mod, status, current, todo, priority, file_ = row_data
    if priority == "CRITICAL": row_bg = BG_RED
    elif priority == "HIGH":   row_bg = BG_ORANGE
    elif priority == "MEDIUM": row_bg = BG_AMBER
    else:                      row_bg = BG_BLUE
    vals = [num, feat, mod, status, current, todo, priority, file_]
    for ci, v in enumerate(vals, 1):
        c = ws4.cell(r, ci); c.value = v
        if ci == 1:   sc(c, BG_DARK, FG_WHITE, True, 10, "center")
        elif ci == 2: sc(c, row_bg, FG_DARK, True, 10, "left", True)
        elif ci == 4: paint_status(ws4, r, ci, status)
        elif ci == 7: paint_status(ws4, r, ci, priority)
        else:         sc(c, row_bg, FG_DARK, False, 10, "left", ci in {5,6,8})
    ws4.row_dimensions[r].height = 52
    r += 1

widths(ws4, [4, 32, 14, 14, 52, 58, 12, 50])

# ════════════════════════════════════════════════════════════════════════════
# SHEET 5 — IMPLEMENTATION PLAN
# ════════════════════════════════════════════════════════════════════════════
ws5 = wb.create_sheet("Implementation Plan")
main_header(ws5, "RECOMMENDED IMPLEMENTATION PLAN",
    "Ordered by priority — fix critical bugs first, then complete pending features")

r = 3
col_hdr(ws5, r, ["Phase","Task #","Task","Module","Est. Effort","Dependencies","Files to Change","Done?"])
r += 1

plan = [
  ("PHASE 1\nCritical Fixes",1,"Populate clientId/regionId/storeId from login + verify-otp response","Auth","1 hr","Login + verifyOtp must return these from backend","auth_repository.dart",""),
  ("PHASE 1\nCritical Fixes",2,"Implement GET /api/bookings → fix My Bookings page","Bookings","4 hrs","Needs Phase 1 Task 1 (clientId must be correct)","booking_repository.dart, my_bookings_page_mobile.dart",""),
  ("PHASE 1\nCritical Fixes",3,"Fix booking status chip case logic + date display","Bookings","1 hr","Needs Task 2","my_bookings_page_mobile.dart",""),
  ("PHASE 1\nCritical Fixes",4,"Fix breed service IDs (store as int, not string)","Services","2 hrs","None","service_repository.dart",""),
  ("PHASE 1\nCritical Fixes",5,"Fix estimatedTotal (parse price strings as double)","Services","0.5 hr","Task 4","service_repository.dart, booking_draft.dart",""),
  ("PHASE 1\nCritical Fixes",6,"401 interceptor — redirect to login after clearSession()","Auth","1 hr","GoRouter access from non-widget context","api_repository.dart",""),
  ("PHASE 2\nAuth Completion",7,"Rebuild Forgot Password page (email → OTP → new password)","Auth","3 hrs","POST /api/auth/send-otp, POST /api/auth/reset-password","forgot_password_page_mobile.dart, auth_repository.dart",""),
  ("PHASE 2\nAuth Completion",8,"Implement AuthRepository.resetPassword() call","Auth","1 hr","Task 7","auth_repository.dart",""),
  ("PHASE 3\nProfile & Account",9,"Implement Profile Update (GET + PUT /api/profile)","Account","3 hrs","None","profile_page_mobile.dart, auth_repository.dart (or new profile_repository.dart)",""),
  ("PHASE 3\nProfile & Account",10,"Add Cancel Booking to My Bookings","Bookings","2 hrs","Task 2 (My Bookings must be API-driven)","booking_repository.dart, my_bookings_page_mobile.dart",""),
  ("PHASE 4\nPayload Fixes",11,"Fix ClientID → ClientId casing in getGroomerAvailability","Bookings","15 min","None","booking_repository.dart",""),
  ("PHASE 4\nPayload Fixes",12,"Fix duplicate serviceId + packageId for package bookings","Bookings","30 min","None","booking_review_page_mobile.dart, booking_repository.dart",""),
  ("PHASE 4\nPayload Fixes",13,"Verify groomerId=0 vs null for 'No Preference' with backend","Bookings","30 min","Backend confirmation","booking_review_page_mobile.dart",""),
  ("PHASE 4\nPayload Fixes",14,"Verify /api/pets/:id response structure for getPetById","Pets","30 min","Backend confirmation","pet_repository.dart",""),
  ("PHASE 4\nPayload Fixes",15,"Verify /api/service-hours field key for getStoreSchedule","Store","15 min","Backend confirmation","store_repository.dart",""),
  ("PHASE 5\nCleanup",16,"Remove SQLite dead methods (createBooking, updateBookingStatus, getBookedSlotsForDate, getBookingsForDate, getBookingById)","Code","1 hr","After Phase 1 Task 2","booking_repository.dart",""),
  ("PHASE 5\nCleanup",17,"Remove TABLE_USERS, TABLE_PETS, TABLE_SERVICES, TABLE_PACKAGES from DatabaseRepository","Code","30 min","After Phase 5 Task 16","database_repository.dart",""),
  ("PHASE 5\nCleanup",18,"Fix 10 flutter analyze info warnings","Code","1 hr","None","booking_repository.dart, shared_calendar.dart, create_pet_page_mobile.dart, etc.",""),
  ("PHASE 5\nCleanup",19,"Remove 35+ Python dev scripts from project root","Code","15 min","None","project root",""),
  ("PHASE 5\nCleanup",20,"Remove 'Demo OTP' log. Fix log prefixes. Add response body logging.","Code","1 hr","None","auth_bloc.dart, api_repository.dart, booking_date_time_page_mobile.dart, booking_review_page_mobile.dart",""),
  ("PHASE 6\nEnhancements",21,"Reset BookingDraft when user enters booking flow from Home","UX","30 min","None","pet_select_page_mobile.dart OR home_page_mobile.dart",""),
  ("PHASE 6\nEnhancements",22,"Show user notification when Step 1 /api/availability falls back to 60min","UX","30 min","None","booking_date_time_page_mobile.dart",""),
  ("PHASE 6\nEnhancements",23,"Implement 'Add to Calendar' on BookingConfirmedPage","UX","2 hrs","add_2_calendar package or url_launcher","booking_confirmed_page_mobile.dart",""),
  ("PHASE 6\nEnhancements",24,"Add delete confirmation dialog before deleting a pet","UX","30 min","None","my_pets_page_mobile.dart",""),
  ("PHASE 6\nEnhancements",25,"Remove hardcoded $68/$40 price fallbacks from Home + PackagesPage","UX","30 min","None","home_page_mobile.dart, packages_page_mobile.dart",""),
  ("PHASE 6\nEnhancements",26,"Remove hardcoded 'California' location from Home header","UX","15 min","None","home_page_mobile.dart",""),
]

phase_seen = {}
for phase, num, task, module, effort, deps, files, done in plan:
    phase_key = phase
    if phase_key not in phase_seen:
        phase_seen[phase_key] = True
        # merge group header
        ws5.merge_cells(start_row=r, start_column=1, end_row=r, end_column=8)
        hc = ws5.cell(r, 1)
        hc.value = phase.replace("\n", " — ")
        ph_bg = BG_RED if "PHASE 1" in phase else (BG_ORANGE if "PHASE 2" in phase else
                (BG_AMBER if "PHASE 3" in phase or "PHASE 4" in phase else
                (BG_BLUE if "PHASE 5" in phase else BG_PURPLE)))
        hc.fill=F(ph_bg); hc.font=Font(bold=True,color=FG_WHITE,size=11,name="Calibri")
        hc.alignment=A("left","center"); ws5.row_dimensions[r].height=22
        r += 1

    row_bg = BG_RED if "PHASE 1" in phase else (BG_ORANGE if "PHASE 2" in phase else
             (BG_AMBER if "PHASE 3" in phase or "PHASE 4" in phase else
             (BG_BLUE if "PHASE 5" in phase else BG_PURPLE)))
    vals = [phase.replace("\n"," "), num, task, module, effort, deps, files, done]
    for ci, v in enumerate(vals, 1):
        c = ws5.cell(r, ci); c.value = v
        if ci == 1: sc(c, BG_DARK, FG_WHITE, True, 9, "center", True)
        elif ci == 2: sc(c, row_bg, FG_DARK, True, 10, "center")
        elif ci == 8:
            c.fill=F(BG_WHITE); c.border=thin_border()
            c.alignment=A("center","center")
        else: sc(c, row_bg, FG_DARK, False, 10, "left", ci in {3,6,7})
    ws5.row_dimensions[r].height = 36
    r += 1

widths(ws5, [18, 6, 45, 14, 10, 40, 55, 8])

# ════════════════════════════════════════════════════════════════════════════
# SHEET 6 — LOCAL DB / HARDCODED DATA
# ════════════════════════════════════════════════════════════════════════════
ws6 = wb.create_sheet("Local DB & Hardcoded")
main_header(ws6, "LOCAL DB / MOCK / HARDCODED DATA AUDIT",
    "Every SQLite call, hardcoded price/duration, and fallback value in production code")

r = 3
col_hdr(ws6, r, ["#","File","Method / Line","Type","Current Source","Required Source","Used in Prod?","Action","Severity"])
r += 1

local_items = [
  (1,"booking_repository.dart","getAllBookings()","LOCAL DB – SQLite","SQLite TABLE_BOOKINGS query","GET /api/bookings","YES – MyBookingsPage","Replace with API","CRITICAL"),
  (2,"booking_repository.dart","getUpcomingBookings()","LOCAL DB – SQLite","SQLite: status!=CANCELLED AND start_time>=now","GET /api/bookings?status=upcoming","YES – MyBookingsPage tab 0","Replace with API","CRITICAL"),
  (3,"booking_repository.dart","getPastBookings()","LOCAL DB – SQLite","SQLite: start_time < now","GET /api/bookings?status=past","YES – MyBookingsPage tab 1","Replace with API","CRITICAL"),
  (4,"booking_repository.dart","getBookingById()","LOCAL DB – SQLite","SQLite query by id","GET /api/bookings/:id","NO – not called from any screen","Remove or replace when detail page added","HIGH"),
  (5,"booking_repository.dart","createBooking()","LOCAL DB – SQLite","SQLite insert to TABLE_BOOKINGS","Not needed — createBookingApi() used","NO – never called in booking flow","DEPRECATE / REMOVE","HIGH"),
  (6,"booking_repository.dart","updateBookingStatus()","LOCAL DB – SQLite","SQLite UPDATE status","PATCH /api/bookings/:id","NO – only via cancelBooking() which is unused","Replace when cancel added","MEDIUM"),
  (7,"booking_repository.dart","getBookedSlotsForDate()","LOCAL DB – SQLite","SQLite: slot LIKE date%","Part of /api/groomer-availability response","NO – not called in availability flow","REMOVE – dead code","MEDIUM"),
  (8,"booking_repository.dart","getBookingsForDate()","LOCAL DB – SQLite","SQLite: slot LIKE date%","Part of /api/groomer-availability response","NO – test mocks only","REMOVE – dead code in production","MEDIUM"),
  (9,"booking_date_time_page_mobile.dart","Line ~97: int durationMinutes = 60","HARDCODED FALLBACK","Literal 60 minutes","GET /api/availability totalDurationMinutes","YES – when Step 1 fails","Keep as fallback; add log warning + user notice","MEDIUM"),
  (10,"home_page_mobile.dart","Lines 783-786: '\$68', '\$40'","HARDCODED PRICE","Literal price strings","API Packages[].Price","YES – homepage package cards","Remove; show API price or 'Contact for pricing'","HIGH"),
  (11,"packages_page_mobile.dart","Lines ~100-104: '\$68', '\$40'","HARDCODED PRICE","Literal price strings","API Packages[].Price","YES – packages page","Remove hardcoded fallbacks","HIGH"),
  (12,"service_repository.dart","Duration fallbacks: '60','45','90'","HARDCODED DURATION","Literal strings in min","API Breeds[].Grooming.TimeinMinutes","YES – when TimeinMinutes missing","Acceptable last-resort fallback only; add log warning","LOW"),
  (13,"profile_page_mobile.dart","Line ~32: '+(817) 123-4567'","HARDCODED PLACEHOLDER","Literal phone string","Session user data or GET /api/profile","YES – always shown in phone field","Remove; read from session or show empty","HIGH"),
  (14,"home_page_mobile.dart","'California' location string","HARDCODED UI TEXT","Literal","User location / store location","YES – header always","Read from session user or remove","LOW"),
  (15,"auth_bloc.dart","'Demo OTP: $otp' log","MISLEADING LOG","sendOtp returns 'sent' string","—","YES – logged always","Remove 'Demo OTP' message","LOW"),
  (16,"booking_repository.dart","Lines 32,67: 'SHEAR-001','DWG-001'","HARDCODED IDs","Literal strings","session.clientId/regionId/storeId (from login response)","YES – ALL availability+booking calls","Fix saveClientId/saveRegionId/saveStoreId in auth_repository","CRITICAL"),
  (17,"booking_review_page_mobile.dart","Lines 139-141: 'SHEAR-001','DWG-001'","HARDCODED IDs","Literal strings","Same as above","YES – create booking call","Same fix as above","CRITICAL"),
  (18,"database_repository.dart","TABLE_USERS, TABLE_PETS, TABLE_SERVICES, TABLE_PACKAGES schemas","LOCAL DB – unused tables","SQLite tables defined but never read in production","API for all data","NO – zero production reads","Remove these tables after API migration","MEDIUM"),
]

for row_data in local_items:
    sev = row_data[8]
    row_bg = BG_RED if "CRITICAL" in sev else (BG_ORANGE if "HIGH" in sev else (BG_AMBER if "MEDIUM" in sev else BG_BLUE))
    for ci, v in enumerate(row_data, 1):
        c = ws6.cell(r, ci); c.value = v
        if ci == 1: sc(c, BG_DARK, FG_WHITE, True, 10, "center")
        elif ci == 9: paint_status(ws6, r, ci, sev)
        else: sc(c, row_bg, FG_DARK, False, 10, "left", ci in {3,4,5,6,8})
    ws6.row_dimensions[r].height = 40
    r += 1

widths(ws6, [4, 40, 32, 22, 38, 38, 14, 38, 12])

# ════════════════════════════════════════════════════════════════════════════
# SHEET 7 — BOOKING FLOW (step-by-step)
# ════════════════════════════════════════════════════════════════════════════
ws7 = wb.create_sheet("Booking Flow")
main_header(ws7, "COMPLETE BOOKING FLOW — Step by Step",
    "Home → Pet Select → Service → Date/Time → Review → Confirm → My Bookings")

r = 3
col_hdr(ws7, r, ["Step","Screen","Action","Data Source","API Called","startTime/endTime Source","Status","Issues"])
r += 1

flow = [
  ("1","Home / PetSelectPage","User taps Book Now / Book Appointment CTA","—","—","—","COMPLETE","⚠️ BookingDraft NOT reset here — stale data from abandoned booking may persist."),
  ("2","PetSelectPage","PetBloc loads pets; user selects one; taps Select & Continue","GET /api/pets (via PetBloc)","GET /api/pets (already loaded)","—","COMPLETE","Empty state shown if no pets. Add Pet flow works."),
  ("2a","CreatePetPage","User creates new pet; photo required","Form + /api/pet-weights for weight dropdown","POST /api/pets (multipart) + GET /api/pet-weights","—","COMPLETE","allVaccinatedCurrent sent as string 'true'/'false'."),
  ("3","BookingServicePage","ServiceBloc loads services; user selects service/package + add-ons","GET /api/service-packages (ServiceBloc)","GET /api/service-packages","—","PARTIAL","Breed service IDs stored as 'breed_X_grooming' strings → int.tryParse null downstream. Price shows $0.00."),
  ("4","BookingDateTimePage Step 1","POST /api/availability → get duration + price","BookingDraft (serviceId, packageId, addOnIds, groomerId, date)","POST /api/availability","—","COMPLETE","clientId/regionId/storeId hardcoded fallback. Step 1 failure is silent (60min fallback)."),
  ("4a","BookingDateTimePage Step 2","GET /api/groomer-availability → groomer chips + slots","BookingDraft.apiDurationMinutes (from Step 1)","GET /api/groomer-availability","—","COMPLETE","Uses backend duration. Store closed / holiday / no-groomers handled."),
  ("4b","BookingDateTimePage","User taps time slot","_availableSlots from API","—","Backend slot.startTime + slot.endTime","COMPLETE","Full slot object stored. endTime from backend only. ✅"),
  ("4c","BookingDateTimePage","User changes groomer","_loadedGroomers from API","GET /api/groomer-availability (re-called)","—","COMPLETE","Slot cleared on groomer change. Correct."),
  ("4d","BookingDateTimePage","User changes date","Calendar","POST /api/availability + GET /api/groomer-availability","—","COMPLETE","Both steps re-called. Slot + endTime + selectedSlot all cleared."),
  ("5","BookingReviewPage","Displays review summary","BookingDraft snapshot","—","—","COMPLETE","Pet photo rendered with BASE_URL prefix for relative paths. Edit links work."),
  ("5a","BookingReviewPage","Pre-confirm re-validation","BookingDraft","POST /api/availability","endTime possibly corrected from backend","COMPLETE","Slot still-available check by startTime+endTime. endTime correction implemented."),
  ("5b","BookingReviewPage","POST /api/bookings","BookingDraft + session","POST /api/bookings","startTime = backend slot.startTime, endTime = backend slot.endTime (corrected if needed)","COMPLETE","clientId/regionId/storeId hardcoded. GROOMER_NOT_AVAILABLE handled."),
  ("6","BookingConfirmedPage","Shows booking summary from lastBooking snapshot","draft.lastBooking (API response data)","—","—","COMPLETE","Shows bookingId, pet, service, date, time, duration, price from API."),
  ("6a","BookingConfirmedPage","'View' button → My Bookings","—","—","—","BROKEN","My Bookings always shows 0 items (SQLite never written)."),
  ("7","MyBookingsPage","Loads Upcoming / Past / Cancelled tabs","SQLite TABLE_BOOKINGS (NEVER written)","❌ NO API CALL","—","BROKEN","CRITICAL: GET /api/bookings not implemented. All tabs show 0 items always."),
  ("INTEGRITY","—","startTime source","Backend availableSlots[n].startTime","—","✅ CONFIRMED — never locally calculated","COMPLETE","—"),
  ("INTEGRITY","—","endTime source","Backend availableSlots[n].endTime","—","✅ CONFIRMED — corrected in re-validate if backend changes it","COMPLETE","—"),
  ("INTEGRITY","—","totalDurationMinutes","Backend /api/availability response","—","—","COMPLETE","60min fallback only when API fails."),
  ("INTEGRITY","—","totalPrice","Backend /api/availability response","—","—","COMPLETE","No hardcoded total price. May be null if Step 1 fails."),
  ("INTEGRITY","—","Stale draft prevention after booking","draft.reset() called after confirmed booking","—","—","COMPLETE","✅ Draft cleared after successful booking."),
]

for row_data in flow:
    step, screen, action, source, api, timing, status, issues = row_data
    row_bg = BG_GREEN if "COMPLETE" in status else (BG_RED if "BROKEN" in status else BG_AMBER)
    for ci, v in enumerate(row_data, 1):
        c = ws7.cell(r, ci); c.value = v
        if ci == 1: sc(c, BG_DARK, FG_WHITE, True, 10, "center")
        elif ci == 7: paint_status(ws7, r, ci, status)
        else: sc(c, row_bg, FG_DARK, False, 10, "left", ci in {3,4,5,6,8})
    ws7.row_dimensions[r].height = 36
    r += 1

widths(ws7, [10, 28, 38, 38, 32, 38, 12, 52])

# ════════════════════════════════════════════════════════════════════════════
# SAVE
# ════════════════════════════════════════════════════════════════════════════
out_path = r"d:\projects\shear_heaven_pet_spa\Shear_Heaven_Project_Report.xlsx"
wb.save(out_path)
print(f"✅ Report saved: {out_path}")
