"""
Shear Heaven Pet Spa — API Implementation Status Report
Generates: Shear_Heaven_Status_Report.xlsx
Compares the confirmed Postman collection against the Flutter implementation.
"""
from openpyxl import Workbook
from openpyxl.styles import PatternFill, Font, Alignment, Border, Side
from openpyxl.utils import get_column_letter
import datetime

wb = Workbook()

# ── colours ──────────────────────────────────────────────────────────────────
D   = "111827"   # dark header
W   = "FFFFFF"
T   = "0F766E"   # teal
GN  = "DCFCE7"; FGN = "14532D"   # green
RD  = "FEE2E2"; FRD = "991B1B"   # red
AM  = "FEF3C7"; FAM = "78350F"   # amber
OR  = "FFEDD5"; FOR = "7C2D12"   # orange
BL  = "DBEAFE"; FBL = "1E3A5F"   # blue
GY  = "F3F4F6"; FGY = "374151"   # grey

def F(h): return PatternFill("solid", fgColor=h)
def Ft(bold=False, color=D, size=10):
    return Font(bold=bold, color=color, size=size, name="Calibri")
def A(h="left", v="center", wrap=False):
    return Alignment(horizontal=h, vertical=v, wrap_text=wrap)
def bdr():
    s = Side(style="thin", color="D1D5DB")
    return Border(left=s, right=s, top=s, bottom=s)

def cell(c, bg=W, fg=D, bold=False, size=10, h="left", wrap=False):
    c.fill = F(bg); c.font = Ft(bold, fg, size)
    c.alignment = A(h, "center", wrap); c.border = bdr()

def banner(ws, row, text, bg=D, fg=W, size=14, cols=10):
    ws.merge_cells(start_row=row, start_column=1, end_row=row, end_column=cols)
    c = ws.cell(row, 1); c.value = text
    c.fill=F(bg); c.font=Font(bold=True, color=fg, size=size, name="Calibri")
    c.alignment=A("center","center"); ws.row_dimensions[row].height = 32

def sub_banner(ws, row, text, bg=T, cols=10):
    ws.merge_cells(start_row=row, start_column=1, end_row=row, end_column=cols)
    c = ws.cell(row, 1); c.value = text
    c.fill=F(bg); c.font=Font(color=W, size=9, italic=True, name="Calibri")
    c.alignment=A("center","center"); ws.row_dimensions[row].height = 16

def hdr(ws, row, labels, bg=D, fg=W):
    for ci, lbl in enumerate(labels, 1):
        c = ws.cell(row, ci); c.value = lbl
        c.fill=F(bg); c.font=Font(bold=True,color=fg,size=10,name="Calibri")
        c.alignment=A("center","center",True); c.border=bdr()
    ws.row_dimensions[row].height = 28

def status_color(val):
    v = str(val).upper()
    if any(x in v for x in ["COMPLETE","DONE","YES"]):    return GN, FGN
    if any(x in v for x in ["CRITICAL","BROKEN","NO"]):  return RD, FRD
    if any(x in v for x in ["HIGH"]):                     return OR, FOR
    if any(x in v for x in ["MEDIUM","PARTIAL"]):         return AM, FAM
    if any(x in v for x in ["LOW","PENDING","NOT IMPL"]): return BL, FBL
    return W, D

def paint(ws, row, col, val):
    bg, fg = status_color(val)
    c = ws.cell(row, col); c.value = val
    c.fill=F(bg); c.font=Font(bold=True,color=fg,size=10,name="Calibri")
    c.alignment=A("center","center"); c.border=bdr()

def section(ws, row, title, bg=T, cols=10):
    ws.merge_cells(start_row=row, start_column=1, end_row=row, end_column=cols)
    c = ws.cell(row, 1); c.value = title
    c.fill=F(bg); c.font=Font(bold=True,color=W,size=11,name="Calibri")
    c.alignment=A("left","center"); ws.row_dimensions[row].height = 22
    return row + 1

def widths(ws, wlist):
    for i, w in enumerate(wlist, 1):
        ws.column_dimensions[get_column_letter(i)].width = w

TODAY = datetime.date.today().strftime("%d %B %Y")

# ════════════════════════════════════════════════════════════════════════════
# SHEET 1 — DASHBOARD  (one glance: complete vs pending)
# ════════════════════════════════════════════════════════════════════════════
ws1 = wb.active
ws1.title = "Dashboard"
banner(ws1, 1, "SHEAR HEAVEN PET SPA — API Implementation Status")
sub_banner(ws1, 2, f"Audit: {TODAY}  |  Source of truth: Postman collection  |  base: https://shear-heaven-api.genzcodershub.com")

# ── score tiles ──────────────────────────────────────────────────────────────
tiles = [
    ("COMPLETE",   "18",  GN, FGN),
    ("PARTIAL",    "4",   AM, FAM),
    ("NOT IMPL",   "8",   RD, FRD),
    ("CRITICAL BUGS", "5", RD, FRD),
    ("HIGH FIXES", "6",   OR, FOR),
]
COLS = 2   # cells per tile
r = 4
for ti, (lbl, val, bg, fg) in enumerate(tiles):
    sc = ti*COLS + 1
    ws1.merge_cells(start_row=r,   start_column=sc, end_row=r,   end_column=sc+COLS-1)
    ws1.merge_cells(start_row=r+1, start_column=sc, end_row=r+1, end_column=sc+COLS-1)
    c1 = ws1.cell(r,   sc); c1.value=lbl
    c1.fill=F(D); c1.font=Font(bold=True,color=W,size=9,name="Calibri")
    c1.alignment=A("center","center"); ws1.row_dimensions[r].height=18
    c2 = ws1.cell(r+1, sc); c2.value=val
    c2.fill=F(bg); c2.font=Font(bold=True,color=fg,size=22,name="Calibri")
    c2.alignment=A("center","center"); ws1.row_dimensions[r+1].height=36

r = 7
# ── module status ────────────────────────────────────────────────────────────
r = section(ws1, r, "MODULE QUICK STATUS")
hdr(ws1, r, ["Module","Status","Key Facts"])
r += 1
modules = [
    ("AUTH — Login / Signup / OTP / Logout / Refresh", "COMPLETE",
     "All 6 auth endpoints wired. Tokens in FlutterSecureStorage. Auto-refresh interceptor works."),
    ("AUTH — Forgot Password / Reset Password", "NOT IMPL",
     "ForgotPasswordPage exists but has NO email field and makes NO API call. Button just navigates to login. AuthRepository.resetPassword() throws UnimplementedError."),
    ("PETS — Full CRUD", "COMPLETE",
     "GET/POST/PUT/DELETE /api/pets all wired via PetRepository. Multipart photo upload works. DOB, gender, vaccination fields all sent."),
    ("DATA APIs — Groomers / Holidays / Service-Hours / Pet-Weights / Service-Packages", "COMPLETE",
     "All 5 read endpoints wired via StoreRepository and ServiceRepository. Called at app startup or on-demand."),
    ("BOOKING — POST /api/availability (Step 1 + re-validate)", "COMPLETE",
     "Called twice: once in DateTimePage (get duration+price), once in ReviewPage (re-validate slot). totalDurationMinutes and totalPrice from API. endTime corrected from backend if changed."),
    ("BOOKING — GET /api/groomer-availability (all/single/selected)", "COMPLETE",
     "All 3 query modes supported via getGroomerAvailability(). Store closed, holiday, unavailable groomer, no-preference union, slot staleness all handled."),
    ("BOOKING — POST /api/bookings (create)", "COMPLETE",
     "Full payload wired. startTime/endTime from backend slot. GROOMER_NOT_AVAILABLE handled. Duplicate-submit guard. Draft reset after success."),
    ("BOOKING — My Bookings (GET /api/bookings)", "NOT IMPL",
     "BROKEN: getAllBookings/getUpcoming/getPast all query SQLite which is NEVER written. My Bookings always shows 0 items. GET /api/bookings endpoint not integrated."),
    ("ADMIN APIs (Groomer/Holiday/StoreHours/WorkingHours/Unavailability CRUD)", "NOT IMPL",
     "No Flutter admin screens exist. These are backend-only admin routes — not needed in the customer app unless an admin panel is added."),
    ("GROOMER-AVAILABILITY POST body (groomerIds as array)", "PARTIAL",
     "Current code only uses GET with query params. The POST body variant (groomerIds:[1,2]) is not used but GET comma-separated groomerIds works. Low risk."),
    ("clientId / regionId / storeId populated from login", "NOT IMPL",
     "CRITICAL: saveClientId/saveRegionId/saveStoreId are NEVER called. All booking APIs fall back to hardcoded 'SHEAR-001'/'DWG-001'. Must extract from login response."),
    ("Profile Update (PUT /api/profile)", "NOT IMPL",
     "No profile update endpoint in Postman collection either. Save Changes on ProfilePage is a no-op. Implement when backend adds the endpoint."),
]
for mod, status, facts in modules:
    bg, fg = status_color(status)
    row_bg = bg
    c1 = ws1.cell(r, 1); c1.value = mod
    cell(c1, D, W, True, 10, "left")
    paint(ws1, r, 2, status)
    c3 = ws1.cell(r, 3); c3.value = facts
    cell(c3, row_bg, D if row_bg != RD else FRD, False, 10, "left", True)
    ws1.row_dimensions[r].height = 40
    r += 1

widths(ws1, [48, 14, 80])

# ════════════════════════════════════════════════════════════════════════════
# SHEET 2 — API-BY-API  (every Postman endpoint vs Flutter)
# ════════════════════════════════════════════════════════════════════════════
ws2 = wb.create_sheet("API by API")
banner(ws2, 1, "EVERY API ENDPOINT — Postman Collection vs Flutter Implementation", cols=11)
sub_banner(ws2, 2, "Green = fully integrated  |  Amber = partial / issues  |  Red = not implemented or broken", cols=11)

r = 3
hdr(ws2, r, ["#","Method","Endpoint","Postman Group","Status",
             "Flutter Repository :: Method","Called From",
             "Request (confirmed from Postman)","Response Fields Used",
             "Issues / Gaps","Priority"])
r += 1

# cols: num, method, endpoint, group, status, repo, caller, request, response, issues, priority
apis = [
# ── HEALTH ──────────────────────────────────────────────────────────────────
(1,"GET","/health","Health","NOT IMPL",
 "—","—",
 "none","server status",
 "Not needed in mobile app. Ignore.",
 "LOW"),
(2,"GET","/api-docs","Health","NOT IMPL",
 "—","—",
 "none","Swagger UI",
 "Not needed in mobile app. Ignore.",
 "LOW"),
# ── AUTH ────────────────────────────────────────────────────────────────────
(3,"POST","/api/auth/signup","Auth","COMPLETE",
 "AuthRepository.register()","AuthBloc._onRegisterSubmitted",
 "name, email, mobile, password, confirmPassword, clientId, regionId, storeId",
 "success, message, errors[]",
 "confirmPassword hardcoded = password (no separate confirm field in UI). clientId/regionId/storeId always empty string at signup (never set from login).",
 "MEDIUM"),
(4,"POST","/api/auth/login","Auth","COMPLETE",
 "AuthRepository.login()","AuthBloc._onLoginSubmitted",
 "email, password",
 "data.accessToken, data.refreshToken, data.user",
 "CRITICAL: clientId/regionId/storeId fields from login response NEVER extracted and saved. Must call session.saveClientId/RegionId/StoreId() here.",
 "CRITICAL"),
(5,"POST","/api/auth/send-otp","Auth","COMPLETE",
 "AuthRepository.sendOtp()","AuthBloc._onSendOtpSubmitted",
 "email, clientId, regionId, storeId",
 "success, message",
 "Called twice during signup flow (register + sendOtp event). Logs 'Demo OTP' — misleading label.",
 "LOW"),
(6,"POST","/api/auth/verify-otp","Auth","COMPLETE",
 "AuthRepository.verifyOtp()","AuthBloc._onVerifyOtpSubmitted",
 "email (from pendingEmail), otp",
 "data.accessToken, data.refreshToken, data.user",
 "user = data['user'] ?? data — if 'user' key absent entire data object saved as session user (includes tokens). Also need to extract clientId/regionId/storeId here.",
 "MEDIUM"),
(7,"POST","/api/auth/refresh-token","Auth","COMPLETE",
 "ApiRepository Dio interceptor (auto on 401)","Automatic — triggers on 401 response",
 "refreshToken",
 "data.accessToken (new token saved)",
 "On refresh failure: clearSession() called but user NOT redirected to login screen. App stays on current screen with cleared credentials.",
 "HIGH"),
(8,"POST","/api/auth/logout","Auth","COMPLETE",
 "AuthRepository.logout()","AuthBloc._onLogoutSubmitted",
 "refreshToken",
 "—",
 "Session cleared even if API call fails. Correct behaviour.",
 "DONE"),
# ── DATA APIs ───────────────────────────────────────────────────────────────
(9,"GET","/api/groomers","Data APIs","COMPLETE",
 "StoreRepository.getGroomers()","App startup (StoreRepository.initialize)",
 "x-client-id, x-region-id, x-store-id headers (from session)",
 "data.Groomers[] — id, groomerCode, firstName, lastName, role, type",
 "Loaded at startup, cached in memory. Not used in booking UI directly (groomer-availability provides groomers). clientId/regionId/storeId never set so headers are null — backend may reject.",
 "HIGH"),
(10,"GET","/api/holidays","Data APIs","COMPLETE",
 "StoreRepository._loadHolidays()","App startup",
 "headers only",
 "data.HolidayList[].Date (MM/DD/YYYY), .name, .description",
 "Date format assumed MM/DD/YYYY. isHoliday() parsing hardcoded for that format. No refresh during session.",
 "LOW"),
(11,"GET","/api/service-hours","Data APIs","PARTIAL",
 "StoreRepository.getStoreSchedule()","App startup",
 "headers only",
 "data.HolidayList[] — Postman confirms key IS 'HolidayList' even for service-hours. So key assumption is CORRECT.",
 "Key name verified correct from Postman. However this data is redundant — store.operationalHours comes from /api/groomer-availability response which is the live source used by booking UI.",
 "LOW"),
(12,"GET","/api/service-packages","Data APIs","COMPLETE",
 "ServiceRepository.getBookingServices()","ServiceBloc.InitializeServices",
 "x-client-id, x-region-id, x-store-id headers",
 "data.Breeds[], data.Packages[], data.AddOns[], data['Walk In Services'][]",
 "Breed service IDs fall back to 'breed_X_grooming' strings when ServiceId key missing → int.tryParse returns null downstream. Prices stored as '$45' strings not doubles → estimatedTotal always $0.",
 "HIGH"),
(13,"GET","/api/pet-weights","Data APIs","COMPLETE",
 "StoreRepository.getPetWeights()","CreatePetPage._loadWeights()",
 "headers only",
 "data.petWeights[].label",
 "Falls back to ['Small','Medium','Large'] if empty. No error shown to user on failure.",
 "LOW"),
# ── PETS ────────────────────────────────────────────────────────────────────
(14,"GET","/api/pets","Pets","COMPLETE",
 "PetRepository.getAllPets()","PetBloc.InitializePets/GetAllPets",
 "Bearer token (Authorization header)",
 "data.userId, data.pets[] → id, petName, breed, weight, age, gender, dateOfBirth, notesAllergies, profilePictureUrl, allVaccinatedCurrent, lastVaccinatedDate, behaviorNotes",
 "Postman confirms response wraps pets in data.pets — code correctly extracts response['data']['pets']. _mapFromApi() maps to DB constant keys. No issues.",
 "DONE"),
(15,"GET","/api/pets/:id","Pets","PARTIAL",
 "PetRepository.getPetById()","MyBookingsPage enrichment loop (no BLoC)",
 "Bearer token + path param id",
 "Assumed flat response — Postman shows same structure as list item",
 "getPetById passes full response directly to _mapFromApi(). If API returns {data:{pet:{...}}} (likely from Postman 'Get Pet by ID'), extraction fails silently. Verify response shape.",
 "MEDIUM"),
(16,"POST","/api/pets","Pets","COMPLETE",
 "PetRepository.createPet()","PetBloc.CreatePet",
 "multipart: profilePicture(file), petName, breed, weight, age, dateOfBirth, gender, notesAllergies, allVaccinatedCurrent, lastVaccinatedDate, behaviorNotes",
 "data.pet.id (Postman shows data.pet.id from 201 response)",
 "Postman test script extracts json.data.pet.id — but Flutter code does response['id'] ?? response['_id']. Must change to response['data']?['pet']?['id'] to match actual API response.",
 "HIGH"),
(17,"PUT","/api/pets/:id","Pets","COMPLETE",
 "PetRepository.updatePet()","PetBloc.UpdatePet",
 "multipart: same as create (optional fields). Path param: id.",
 "bool success via putMultipart()",
 "putMultipart returns bool only. Cannot distinguish 400 validation error from 500. Consider returning response body for error messages.",
 "MEDIUM"),
(18,"DELETE","/api/pets/:id","Pets","COMPLETE",
 "PetRepository.deletePet()","PetBloc.DeletePet",
 "Bearer token + path param id",
 "bool success via delete()",
 "No delete confirmation dialog in UI before dispatching DeletePet event.",
 "LOW"),
# ── BOOKINGS ────────────────────────────────────────────────────────────────
(19,"POST","/api/availability","Bookings","COMPLETE",
 "BookingRepository.getAvailability()","BookingDateTimePage (Step 1) + BookingReviewPage (re-validate)",
 "ClientId, RegionId, StoreId, date, serviceId?, packageId?, addOnIds[]?, groomerId?\nPostman: serviceId=12, packageId=1, addOnIds=[2,3], groomerId=3",
 "data.totalDurationMinutes, data.totalPrice, data.bookedSlots[], data.availableSlots[]{startTime,endTime,groomerId,groomerName}, data.groomers[], data.workingHours, data.closed, data.holiday",
 "ClientId/RegionId/StoreId hardcoded fallback. For packages: effectiveServiceId=packageId so payload sends both serviceId:packageId AND packageId:packageId — confirm with backend. Step 1 failure falls back to 60min silently.",
 "CRITICAL"),
(20,"POST","/api/bookings","Bookings","COMPLETE",
 "BookingRepository.createBookingApi()","BookingReviewPage._confirmBooking()",
 "ClientId, RegionId, StoreId, petId, serviceId?, packageId?, addOnIds[], groomerId, bookingDate, startTime, endTime\nPostman: groomerId=3, startTime='15:00', endTime='16:00'",
 "data.bookingId, data.status ('confirmed'), data.totalDurationMinutes, data.totalPrice",
 "Postman confirms groomerId=0 is valid for 'No Preference' — backend picks first available. Postman 201 saves bookingId. Flutter correctly handles GROOMER_NOT_AVAILABLE. startTime/endTime always from backend slot.",
 "DONE"),
(21,"GET","/api/bookings","Bookings","NOT IMPL",
 "NOT IMPLEMENTED — getAllBookings/getUpcoming/getPast use SQLite instead","MyBookingsPage._loadBookings()",
 "Not in Postman collection — endpoint exists in backend but no Postman entry provided. Need to confirm query params: status?, userId?, pagination?",
 "—",
 "CRITICAL: SQLite TABLE_BOOKINGS is NEVER written. My Bookings always shows 0 items. Must implement GET /api/bookings and confirm endpoint params with backend team.",
 "CRITICAL"),
# ── GROOMER AVAILABILITY ────────────────────────────────────────────────────
(22,"GET","/api/groomer-availability\n(all groomers — no groomerId)","Groomer Availability","COMPLETE",
 "BookingRepository.getGroomerAvailability() — no groomerId param","BookingDateTimePage._loadAvailability() Step 2 when _selectedGroomer=='any'",
 "date, ClientID, RegionId, StoreId, durationMinutes\nPostman: date=2026-08-19, durationMinutes=60",
 "data.scope='all', data.store{closed,holiday,operationalHours}, data.groomers[]{id,name,available,reason,workingHours,unavailable,bookedSlots,availableWindows,availableSlots[]{startTime,endTime}}",
 "Postman CONFIRMS: key is 'ClientID' (capital D) — but getAvailability POST uses 'ClientId'. These are different endpoints with different casing. The GET groomer-availability correctly uses 'ClientID'. No bug — already correct.",
 "DONE"),
(23,"GET","/api/groomer-availability\n(single groomer — groomerId=N)","Groomer Availability","COMPLETE",
 "BookingRepository.getGroomerAvailability(groomerId: N)","BookingDateTimePage when specific groomer selected",
 "date, groomerId, ClientID, RegionId, StoreId, durationMinutes",
 "data.scope='single', same groomer structure",
 "Postman confirms groomerId as query param — Flutter correctly passes it. Correct.",
 "DONE"),
(24,"GET","/api/groomer-availability\n(selected groomers — groomerIds=1,2)","Groomer Availability","PARTIAL",
 "BookingRepository.getGroomerAvailability(groomerIds: [1,2])\nPasses as query param: groomerIds=1,2 (comma-separated string)",
 "BookingDateTimePage when multiple groomers wanted",
 "date, groomerIds=1,2 (comma-separated), ClientID, RegionId, StoreId, durationMinutes",
 "data.scope='selected', groomers for IDs 1 and 2 only",
 "Postman confirms groomerIds as comma-separated query param. Flutter sends groomerIds.join(',') — CORRECT. However current booking UI only uses 'any' (all) or one specific groomer. The multi-select mode (groomerIds) is available but not triggered from UI.",
 "LOW"),
(25,"POST","/api/groomer-availability\n(POST body — groomerIds as array)","Groomer Availability","PARTIAL",
 "BookingRepository.getGroomerAvailability() — only GET is used currently",
 "Not called from Flutter",
 "Body: {date, groomerIds:[1,2], durationMinutes, ClientID, RegionId, StoreId}",
 "Same as GET selected — data.scope='selected'",
 "POST variant exists for sending groomerIds as array. Flutter always uses GET. No functional gap since GET with comma-separated groomerIds works the same way.",
 "LOW"),
# ── ADMIN (not needed in customer app) ──────────────────────────────────────
(26,"GET/POST/PUT/DELETE","/api/admin/groomers","Admin","NOT IMPL",
 "—","—",
 "ClientID, RegionId, StoreId query params",
 "Groomer CRUD",
 "Admin-only endpoints. No admin panel in customer Flutter app. Not required unless admin features are added.",
 "NOT NEEDED"),
(27,"GET/POST/PUT/DELETE","/api/admin/holidays","Admin","NOT IMPL",
 "—","—","ClientID, RegionId, StoreId","Holiday CRUD",
 "Admin-only. Not required in customer app.",
 "NOT NEEDED"),
(28,"GET/POST/PUT/DELETE","/api/admin/store-hours","Admin","NOT IMPL",
 "—","—","ClientID, RegionId, StoreId","Store hours CRUD",
 "Admin-only. Not required in customer app.",
 "NOT NEEDED"),
(29,"GET/POST/PUT/DELETE","/api/admin/groomer-hours","Admin","NOT IMPL",
 "—","—","groomerId, ClientID, RegionId, StoreId","Groomer working hours CRUD",
 "Admin-only. Not required in customer app.",
 "NOT NEEDED"),
(30,"GET/POST/PUT/DELETE","/api/admin/groomer-unavailability","Admin","NOT IMPL",
 "—","—","groomerId, ClientID, RegionId, StoreId","Groomer unavailability CRUD",
 "Admin-only. Not required in customer app.",
 "NOT NEEDED"),
]

METHOD_BG = {"GET":BL,"POST":GN,"PUT":AM,"DELETE":RD,"PATCH":OR,
             "GET/POST/PUT/DELETE":GY}

for row in apis:
    num,method,endpoint,group,status,repo,caller,req,resp,issues,priority = row
    s_bg, s_fg = status_color(status)
    p_bg, p_fg = status_color(priority)
    vals = [num,method,endpoint,group,status,repo,caller,req,resp,issues,priority]
    for ci, v in enumerate(vals, 1):
        c = ws2.cell(r, ci); c.value = v
        if ci == 1:
            cell(c, D, W, True, 10, "center")
        elif ci == 2:
            mbg = METHOD_BG.get(method, W)
            cell(c, mbg, D, True, 10, "center")
        elif ci == 5:
            paint(ws2, r, ci, status)
        elif ci == 11:
            paint(ws2, r, ci, priority)
        else:
            wrap = ci in {3,6,7,8,9,10}
            cell(c, s_bg, D, False, 10, "left", wrap)
    ws2.row_dimensions[r].height = 52
    r += 1

widths(ws2, [4, 10, 34, 16, 14, 36, 28, 52, 46, 58, 12])

# ════════════════════════════════════════════════════════════════════════════
# SHEET 3 — WHAT IS COMPLETE
# ════════════════════════════════════════════════════════════════════════════
ws3 = wb.create_sheet("Complete")
banner(ws3, 1, "WHAT IS COMPLETE — Fully Implemented & Working", bg=T)
sub_banner(ws3, 2, "All items below are realtime API-driven. No SQLite, no hardcoded data.")
r = 3
hdr(ws3, r, ["#","Feature","Postman Endpoint","Flutter File :: Method","Verified Correct?"])
r += 1
completed = [
    (1, "User Login",
     "POST /api/auth/login",
     "AuthRepository.login() → AuthBloc._onLoginSubmitted",
     "YES — tokens saved to FlutterSecureStorage, session saved to SharedPrefs"),
    (2, "User Signup",
     "POST /api/auth/signup → POST /api/auth/send-otp",
     "AuthRepository.register() + sendOtp() → AuthBloc._onRegisterSubmitted",
     "YES — two-step: signup sends OTP, OTP page verifies"),
    (3, "Send OTP",
     "POST /api/auth/send-otp",
     "AuthRepository.sendOtp() → AuthBloc._onSendOtpSubmitted",
     "YES — pendingEmail stored for subsequent verify-otp call"),
    (4, "Verify OTP",
     "POST /api/auth/verify-otp",
     "AuthRepository.verifyOtp() → AuthBloc._onVerifyOtpSubmitted",
     "YES — accessToken + refreshToken extracted and saved securely"),
    (5, "Auto Token Refresh (401 interceptor)",
     "POST /api/auth/refresh-token",
     "ApiRepository Dio interceptor — automatic",
     "YES — uses separate Dio instance to avoid loop. New tokens saved. Original request retried."),
    (6, "Logout",
     "POST /api/auth/logout",
     "AuthRepository.logout() → AuthBloc._onLogoutSubmitted",
     "YES — refreshToken invalidated on server. Local session cleared even on API failure."),
    (7, "Get All Pets",
     "GET /api/pets",
     "PetRepository.getAllPets() → PetBloc.InitializePets",
     "YES — response['data']['pets'] correctly extracted. Mapped via _mapFromApi()."),
    (8, "Create Pet (multipart with photo)",
     "POST /api/pets",
     "PetRepository.createPet() → PetBloc.CreatePet",
     "PARTIAL — all fields sent correctly. But pet ID extracted as response['id'] instead of response['data']['pet']['id'] per Postman test script."),
    (9, "Update Pet (multipart)",
     "PUT /api/pets/:id",
     "PetRepository.updatePet() → PetBloc.UpdatePet",
     "YES — existing network photo URLs skipped correctly. Edit mode via GoRouter extra."),
    (10, "Delete Pet",
     "DELETE /api/pets/:id",
     "PetRepository.deletePet() → PetBloc.DeletePet",
     "YES — returns bool. Pet list refreshed after deletion."),
    (11, "Load Groomers (startup cache)",
     "GET /api/groomers",
     "StoreRepository.getGroomers() — called in initialize()",
     "YES — data.Groomers[] extracted. Used as a startup cache (not used live in booking UI)."),
    (12, "Load Holidays (startup cache)",
     "GET /api/holidays",
     "StoreRepository._loadHolidays() — called in initialize()",
     "YES — data.HolidayList[].Date parsed as MM/DD/YYYY. isHoliday() helper works. SharedCalendar disables holiday dates."),
    (13, "Load Service Hours (startup)",
     "GET /api/service-hours",
     "StoreRepository.getStoreSchedule() — called in initialize()",
     "YES — Postman confirms key IS 'HolidayList' for service-hours too. Key assumption verified correct."),
    (14, "Load Service Packages",
     "GET /api/service-packages",
     "ServiceRepository.getBookingServices() → ServiceBloc.InitializeServices",
     "YES — Breeds, Packages, AddOns, Walk In Services all parsed. Drives BookingServicePage, ServicesPage, HomePage."),
    (15, "Load Pet Weights",
     "GET /api/pet-weights",
     "StoreRepository.getPetWeights() → CreatePetPage._loadWeights()",
     "YES — data.petWeights[].label populates weight dropdown dynamically."),
    (16, "Booking Step 1 — Get Duration + Price",
     "POST /api/availability",
     "BookingRepository.getAvailability() → BookingDateTimePage._loadAvailability()",
     "YES — totalDurationMinutes drives Step 2 durationMinutes. totalPrice stored in draft. endTime from API."),
    (17, "Booking Step 2 — Groomer Slots",
     "GET /api/groomer-availability",
     "BookingRepository.getGroomerAvailability() → BookingDateTimePage._loadAvailability()",
     "YES — store.closed, store.holiday, groomer chips, slot grid, unavailable reasons all handled from API response."),
    (18, "Select Time Slot (from backend)",
     "Backend slot: {startTime, endTime, groomerId, groomerName}",
     "BookingDraft.setSelectedSlot() — stores full slot object",
     "YES — startTime and endTime 100% from backend. No local time calculation at all."),
    (19, "Slot Staleness Validation",
     "Implicit — slot list refreshed on date/groomer change",
     "BookingDateTimePage._validateSelectedSlot()",
     "YES — stale slot cleared if no longer in availableSlots after reload."),
    (20, "Store Closed / Holiday UI",
     "data.store.closed, data.store.holiday from /api/groomer-availability",
     "BookingDateTimePage — _storeClosed, _holidayName state vars",
     "YES — banners shown, slot grid hidden, Continue button blocked."),
    (21, "Pre-booking Re-validation",
     "POST /api/availability (called again before create)",
     "BookingReviewPage._confirmBooking() Step 1",
     "YES — checks selected slot still in availableSlots. Corrects endTime from backend if it changed."),
    (22, "Create Booking",
     "POST /api/bookings",
     "BookingRepository.createBookingApi() → BookingReviewPage._confirmBooking()",
     "YES — full payload. GROOMER_NOT_AVAILABLE handled. Duplicate-submit guard (_confirming flag). Draft reset after success."),
    (23, "Booking Confirmed Screen",
     "Response: data.bookingId, status, totalDurationMinutes, totalPrice",
     "BookingConfirmedPageMobile — reads draft.lastBooking snapshot",
     "YES — shows API-returned bookingId, price, duration. Pet/service/date from draft snapshot."),
    (24, "Network Status Monitoring",
     "N/A — device connectivity",
     "NetworkService + NetworkStatusWidget",
     "YES — offline banner shown. Connectivity monitored via connectivity_plus."),
]

for num, feat, endpoint, file_, verified in completed:
    bg = GN if "YES" in verified else AM
    for ci, v in enumerate([num, feat, endpoint, file_, verified], 1):
        c = ws3.cell(r, ci); c.value = v
        if ci == 1: cell(c, D, W, True, 10, "center")
        elif ci == 2: cell(c, bg, FGN if bg==GN else FAM, True, 10, "left")
        else: cell(c, bg, D, False, 10, "left", ci in {3,4,5})
    ws3.row_dimensions[r].height = 36
    r += 1

widths(ws3, [4, 40, 40, 50, 60])

# ════════════════════════════════════════════════════════════════════════════
# SHEET 4 — WHAT IS PENDING / BROKEN (with exact fix instructions)
# ════════════════════════════════════════════════════════════════════════════
ws4 = wb.create_sheet("Pending & Broken")
banner(ws4, 1, "WHAT IS PENDING / BROKEN — Exact Fix Required", bg="7F1D1D")
sub_banner(ws4, 2, "Ordered by priority: CRITICAL first  |  Every item has a specific file and action")
r = 3
hdr(ws4, r, ["#","Issue / Feature","Priority","Current Broken Behaviour",
             "Exact Fix Needed","File(s) to Change"])
r += 1

pending = [
# ── CRITICAL ────────────────────────────────────────────────────────────────
(1,"clientId / regionId / storeId — NEVER saved from login","CRITICAL",
 "saveClientId/saveRegionId/saveStoreId exist in SessionService but are NEVER called anywhere in production code. All availability and booking API calls fall back to hardcoded 'SHEAR-001'/'DWG-001'. Only works because those happen to be the real values.",
 "In AuthRepository.login(): after saveSession(user), extract data['clientId'], data['regionId'], data['storeId'] and call session.saveClientId/RegionId/StoreId(). Same in AuthRepository.verifyOtp(). Remove hardcoded fallbacks from booking_repository.dart and booking_review_page_mobile.dart once session values are guaranteed.",
 "auth_repository.dart\nbooking_repository.dart\nbooking_review_page_mobile.dart"),

(2,"My Bookings — ALWAYS shows 0 items","CRITICAL",
 "getAllBookings(), getUpcomingBookings(), getPastBookings() all query SQLite TABLE_BOOKINGS. That table is NEVER written (createBooking() SQLite insert is never called in the booking flow). My Bookings is permanently broken for all real users.",
 "Implement GET /api/bookings in BookingRepository (confirm query params with backend: status?, pagination?). Replace the three SQLite methods in MyBookingsPage with the new API call. Update _BookingCard to read bookingDate, startTime, endTime, status, totalPrice from API response instead of the 'slot' column.",
 "booking_repository.dart\nmy_bookings_page_mobile.dart"),

(3,"Create Pet — wrong response field for pet ID","CRITICAL",
 "PetRepository.createPet() does response['id'] ?? response['_id']. But Postman test script confirms: json.data.pet.id is where the new pet ID lives after a 201 response. Flutter's extraction will always return null.",
 "Change to: response['data']?['pet']?['id'] ?? response['data']?['id'] ?? response['id']. Add null check and throw if still null.",
 "pet_repository.dart → createPet()"),

(4,"Forgot Password — page is completely non-functional","CRITICAL",
 "ForgotPasswordPage has NO email input field. The form only shows two password fields. The 'Update Password' button calls context.goNamed(login) — no API call whatsoever. Users cannot reset their passwords.",
 "Rebuild ForgotPasswordPage as a 3-step flow: (1) Email input → POST /api/auth/send-otp. (2) OTP input → POST /api/auth/verify-otp (or a dedicated reset-OTP endpoint). (3) New password fields → POST /api/auth/reset-password (confirm endpoint exists with backend). Reuse OtpPage widget for step 2.",
 "forgot_password_page_mobile.dart\nauth_repository.dart (add forgotPassword + resetPassword methods)\nauth_bloc.dart (implement _onResetPasswordSubmitted)"),

(5,"AuthRepository.resetPassword() throws UnimplementedError","CRITICAL",
 "AuthBloc._onResetPasswordSubmitted calls repository.resetPassword() which immediately throws UnimplementedError. If this handler is ever triggered, the app crashes.",
 "Implement POST /api/auth/reset-password in AuthRepository or remove the BLoC event entirely until the endpoint is confirmed with backend.",
 "auth_repository.dart → resetPassword()"),

# ── HIGH ────────────────────────────────────────────────────────────────────
(6,"401 clear-session → no redirect to login","HIGH",
 "When token refresh fails in the Dio interceptor, clearSession() is called but the user stays on whatever screen they were on. All subsequent API calls will fail silently because the session is cleared.",
 "After await session.clearSession() in the interceptor's onError, emit or push a navigation event to the login route. Use a GlobalKey<NavigatorState> registered at app startup, or a stream that AuthBloc listens to.",
 "api_repository.dart → interceptor onError\napp.dart (register navigator key)\nauth_bloc.dart (listen to session-cleared stream)"),

(7,"Breed service IDs are strings — int.tryParse returns null","HIGH",
 "When ServiceId key is absent from API, ServiceRepository falls back to 'breed_{breedId}_grooming' string. extractServiceIds() calls int.tryParse on this → returns null → serviceId omitted from /api/availability and /api/bookings payload. Booking for breed services may fail.",
 "Use ServiceId/serviceId integer value only. If ServiceId is missing, use BreedTypeId or breedId as the integer ID. Never store a string like 'breed_X_grooming' as the ID field. Audit all ID fields in getBookingServices() against actual /api/service-packages response.",
 "service_repository.dart → getBookingServices() (Breeds parsing)"),

(8,"estimatedTotal always shows $0.00","HIGH",
 "BookingDraft.estimatedTotal checks 'servicePrice is num'. But breed/walkin service prices are stored as '\$45' strings from ServiceRepository. Check always fails → returns 0.0. Bottom bar on BookingServicePage always shows '$0.00'.",
 "Store prices as double in ServiceRepository (strip '$' and parse). e.g. double.tryParse(price.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0. Then estimatedTotal will work. Also prefer showing apiTotalPrice (from /api/availability) on the review screen over estimatedTotal.",
 "service_repository.dart → getBookingServices() (price storage)\nbooking_draft.dart → estimatedTotal"),

(9,"Get Pet by ID — response extraction may fail","HIGH",
 "getPetById() passes full API response directly to _mapFromApi(). Postman 'Get Pet by ID' likely returns same wrapper as list: {data:{pet:{...}}}. Current code treats the wrapper as the pet object → all fields mapped to null.",
 "Match the same extraction pattern as getAllPets: extract response['data']?['pet'] (or check actual API shape), then pass to _mapFromApi().",
 "pet_repository.dart → getPetById()"),

(10,"Profile page Save Changes does nothing","HIGH",
 "ProfilePageMobile Save Changes calls context.pop() only. No PUT/PATCH API call. Phone field hardcoded to '+(817) 123-4567'. No profile update endpoint in current Postman collection.",
 "Confirm with backend if PUT /api/profile or PATCH /api/auth/profile endpoint exists. Load all profile fields from session user data (name, email, phone from login response). Remove hardcoded phone. Implement API call on save.",
 "profile_page_mobile.dart\nauth_repository.dart (add updateProfile when endpoint confirmed)"),

(11,"Booking status chip — case mismatch + missing PENDING case","HIGH",
 "Postman confirms API returns status: 'confirmed' (lowercase). _statusChip already calls .toUpperCase() so 'confirmed' → 'CONFIRMED' which matches. BUT the else branch shows all other statuses as 'Cancelled' (red). 'PENDING' would show as red 'Cancelled' which is wrong.",
 "Add explicit cases: PENDING → show as 'Pending' (amber), COMPLETED → show as 'Completed' (grey), CANCELLED → 'Cancelled' (red). After GET /api/bookings is implemented, verify all status values the backend returns.",
 "my_bookings_page_mobile.dart → _statusChip()"),

# ── MEDIUM ───────────────────────────────────────────────────────────────────
(12,"Booking date shows 'Aug 4, 2026' hardcoded","MEDIUM",
 "_dateLabel() parses slot column as 'date|time' format. slot is always '' from SQLite. Hardcoded fallback 'Aug 4, 2026' always shown.",
 "After GET /api/bookings is implemented, parse bookingDate and startTime fields directly from the API response object. Remove slot-parsing logic.",
 "my_bookings_page_mobile.dart → _dateLabel()"),

(13,"effectiveServiceId sends duplicate packageId as serviceId","MEDIUM",
 "For packages: effectiveServiceId = packageId. Payload sends both serviceId: packageId AND packageId: packageId. Backend may ignore extra field but it's semantically wrong.",
 "When booking a package, omit serviceId from payload and send packageId only. When booking a breed/walkin service, send serviceId only and omit packageId.",
 "booking_review_page_mobile.dart → _confirmBooking() createPayload\nbooking_repository.dart → getAvailability()"),

(14,"Groomer image URL — multiple key name guessing","MEDIUM",
 "BookingDateTimePage tries g['image'] ?? g['Image'] ?? g['photo'] ?? g['Photo'] ?? g['imagePath'] ?? g['ImagePath'] ?? g['avatar']. If actual API key is different, groomer always shows initial letter fallback.",
 "Check actual /api/groomer-availability response for the groomer image field name. From the Postman response confirmed above, NO image field is present in groomers[] — only id, firstName, lastName, name, role, type, available, reason, workingHours, unavailable, bookedSlots, availableWindows, availableSlots. Remove the image key guessing and use initial always (as the API doesn't return images for groomers in this endpoint).",
 "booking_date_time_page_mobile.dart → groomer chip build"),

(15,"Silent fallback when Step 1 /api/availability fails","MEDIUM",
 "If POST /api/availability returns null or success=false, durationMinutes falls back to 60 silently. User sees slots but the duration used may be wrong.",
 "Show a toast/banner: 'Could not load service duration. Using estimated 60 minutes.' Log at warning level.",
 "booking_date_time_page_mobile.dart → _loadAvailability() Step 1 failure branch"),

(16,"SQLite dead code — createBooking / updateBookingStatus / getBookedSlotsForDate / getBookingsForDate / getBookingById","MEDIUM",
 "These 5 methods exist in BookingRepository and all hit SQLite. None are called in the actual booking flow (which uses createBookingApi). They create confusion and risk of future bugs if accidentally called.",
 "After GET /api/bookings is implemented (fixing My Bookings), remove all 5 SQLite booking methods. Then consider removing DatabaseRepository entirely since pets/services never use it either.",
 "booking_repository.dart\ndatabase_repository.dart (remove TABLE_USERS, TABLE_PETS, TABLE_SERVICES, TABLE_PACKAGES after full migration)"),

# ── LOW ──────────────────────────────────────────────────────────────────────
(17,"Draft not reset when entering booking flow from home","LOW",
 "BookingDraft.reset() is only called after successful booking. If user abandons a booking mid-flow and taps 'Book Now' again, stale pet/service/date/slot may be pre-filled.",
 "Call ServicesLocator.bookingDraft.reset() in PetSelectPage.initState() or when 'Book Now' is tapped on HomePage, to ensure a clean state at the start of each new booking.",
 "pet_select_page_mobile.dart → initState() OR home_page_mobile.dart → Book Now onTap"),

(18,"Groomer image not in API response — remove dead image lookup code","LOW",
 "Postman response confirms groomers[] has no image/photo/avatar field. The multi-key image lookup is dead code.",
 "Remove the imagePath lookup entirely. Always render groomer initial letter in the chip circle.",
 "booking_date_time_page_mobile.dart → groomer chip image builder"),

(19,"'Demo OTP' misleading log","LOW",
 "AuthBloc logs 'Demo OTP: $otp' but sendOtp() always returns the string 'sent'. The log is misleading.",
 "Change to: _log.d('OTP send confirmed for: ${event.email}')",
 "auth_bloc.dart → _onRegisterSubmitted, _onSendOtpSubmitted"),

(20,"Hardcoded price fallbacks $68 / $40 in package cards","LOW",
 "HomePage and PackagesPage show hardcoded '$68' and '$40' as grooming/bath prices when API fields grooming_price/bath_price are absent.",
 "Remove hardcoded values. Show the single API 'price' field or display 'See pricing' if no price available.",
 "home_page_mobile.dart → _buildPackagesList\npackages_page_mobile.dart"),

(21,"'California' hardcoded location in home header","LOW",
 "Home header always shows 'California'. Not from session or API.",
 "Read from session user data if available (check if login response includes location/city). Otherwise hardcode 'Arlington, TX' (the store's actual location) since it is a single-store app.",
 "home_page_mobile.dart → _buildHeader"),

(22,"Delete pet — no confirmation dialog","LOW",
 "Delete is triggered immediately without confirming with the user.",
 "Add AlertDialog: 'Delete {petName}? This cannot be undone.' before dispatching DeletePet event.",
 "my_pets_page_mobile.dart → delete action"),

(23,"'Add to Calendar' button is empty onTap","LOW",
 "Button exists on BookingConfirmedPage with onTap: () {} — does nothing.",
 "Implement using add_2_calendar package or url_launcher to open device calendar with booking title, date and time from draft.lastBooking.",
 "booking_confirmed_page_mobile.dart → Add to Calender button"),

(24,"10 flutter analyze info warnings","LOW",
 "use_null_aware_elements, unnecessary_brace_in_string_interps, curly_braces_in_flow_control, unnecessary_underscores — all info level, none blocking.",
 "Fix all 10 in the flagged files.",
 "booking_repository.dart, booking_review_page_mobile.dart, booking_confirmed_page_mobile.dart, home_page_mobile.dart, create_pet_page_mobile.dart, shared_calendar.dart"),
]

for num, issue, priority, broken, fix, files in pending:
    p_bg, p_fg = status_color(priority)
    for ci, v in enumerate([num, issue, priority, broken, fix, files], 1):
        c = ws4.cell(r, ci); c.value = v
        if ci == 1:   cell(c, D, W, True, 10, "center")
        elif ci == 2: cell(c, p_bg, D, True, 10, "left", True)
        elif ci == 3: paint(ws4, r, ci, priority)
        else:         cell(c, p_bg, D, False, 10, "left", True)
    ws4.row_dimensions[r].height = 60
    r += 1

widths(ws4, [4, 38, 12, 55, 60, 42])

# ════════════════════════════════════════════════════════════════════════════
# SHEET 5 — GROOMER AVAILABILITY DEEP DIVE (confirmed from Postman)
# ════════════════════════════════════════════════════════════════════════════
ws5 = wb.create_sheet("Groomer Availability")
banner(ws5, 1, "GROOMER AVAILABILITY — Postman Response vs Flutter Implementation", bg=T)
sub_banner(ws5, 2, "Verified against actual Postman response. All field names confirmed.")
r = 3

r = section(ws5, r, "API VARIANTS — confirmed from Postman collection", cols=6)
hdr(ws5, r, ["Variant","Method + URL","Key Param","data.scope","Flutter Calls It?","Status"])
r += 1
variants = [
    ("All Groomers","GET /api/groomer-availability?date=...&ClientID=...&RegionId=...&StoreId=...&durationMinutes=60",
     "No groomerId / no groomerIds","'all'","YES — when _selectedGroomer == 'any'","COMPLETE"),
    ("Single Groomer","GET /api/groomer-availability?...&groomerId=1&...",
     "groomerId (integer, single)","'single'","YES — when specific groomer chip selected","COMPLETE"),
    ("Selected Groomers (GET)","GET /api/groomer-availability?...&groomerIds=1,2&...",
     "groomerIds (comma-separated string)","'selected'","YES — when groomerIds list passed to getGroomerAvailability","PARTIAL — UI never triggers multi-select mode"),
    ("Selected Groomers (POST body)","POST /api/groomer-availability body: {groomerIds:[1,2],...}",
     "groomerIds (array in body)","'selected'","NO — Flutter always uses GET","LOW — GET variant works fine"),
]
for row_data in variants:
    v, url, param, scope, called, status = row_data
    s_bg, s_fg = status_color(status)
    for ci, val in enumerate([v, url, param, scope, called, status], 1):
        c = ws5.cell(r, ci); c.value = val
        if ci == 1: cell(c, D, W, True, 10, "left")
        elif ci == 6: paint(ws5, r, ci, status)
        else: cell(c, s_bg, D, False, 10, "left", ci in {2,3,5})
    ws5.row_dimensions[r].height = 36
    r += 1

r += 1
r = section(ws5, r, "RESPONSE FIELDS — confirmed from Postman response body", cols=6)
hdr(ws5, r, ["Response Field","Type","Value (example)","Flutter Reads It?","Where Used","Issue"])
r += 1
resp_fields = [
    ("success","bool","true","YES","All callers check this",""),
    ("data.date","string","'2026-08-19'","NO","Not used in Flutter","No issue — Flutter uses the date from draft"),
    ("data.durationMinutes","int","60","NO","Not used — Flutter uses totalDurationMinutes from /api/availability","No issue"),
    ("data.scope","string","'all' / 'single' / 'selected'","NO","Not used in Flutter","No issue"),
    ("data.store.ClientID","string","'SHEAR-001'","NO","Not used",""),
    ("data.store.closed","bool","false","YES","_storeClosed = isClosed → banner shown, slots hidden","CORRECT"),
    ("data.store.holiday","null / string","null","YES","_holidayName → banner if not null","CORRECT"),
    ("data.store.operationalHours.isOpen","bool","true","NO","Not used — closed field is used instead","Fine"),
    ("data.store.operationalHours.startTime","string","'08:00'","NO","Not extracted — backend computes slots within these hours","Fine — backend handles this"),
    ("data.store.operationalHours.endTime","string","'17:30'","NO","Same",""),
    ("data.groomers[].id","int","1","YES","groomer chip 'id' field → used for filtering + draft","CORRECT. Postman confirms it's an INT not a string. Flutter stores as string via .toString() which is safe for comparison."),
    ("data.groomers[].groomerCode","string","'G001'","NO","Not used in Flutter UI","Fine"),
    ("data.groomers[].firstName","string","'Merisa'","YES","Combined with lastName for chip display name","CORRECT"),
    ("data.groomers[].lastName","string","'Brown'","YES","Combined with firstName","CORRECT"),
    ("data.groomers[].name","string","'Merisa Brown'","YES","Used as fallback if firstName absent","CORRECT"),
    ("data.groomers[].role","string","'Lead Groomer'","YES","Stored in groomer map, shown on chip","CORRECT"),
    ("data.groomers[].type","string","'Groomer' / 'Bather'","YES","Stored in groomer map","CORRECT"),
    ("data.groomers[].available","bool","true","YES","Chip opacity 0.4 if false; slots not loaded for unavailable","CORRECT"),
    ("data.groomers[].reason","null / string","null","YES","Shown below chip if unavailable","CORRECT"),
    ("data.groomers[].workingHours","object","{isWorking, startTime, endTime, effectiveStartTime, effectiveEndTime}","YES","Stored in groomer map","CORRECT — stored but only effectiveStart/End are meaningful for slots"),
    ("data.groomers[].unavailable[]","array","[{startTime:'12:00',endTime:'13:00',reason:'Lunch break',leaveType:'break'}]","YES","Stored in groomer map (unavailable key)","CORRECT — displayed as blocked period info"),
    ("data.groomers[].bookedSlots[]","array","[] (empty in example)","YES","Stored in groomer map","CORRECT — used for display info"),
    ("data.groomers[].availableWindows[]","array","[{startTime:'08:00',endTime:'12:00'},{startTime:'13:00',endTime:'17:30'}]","YES","Stored in groomer map","CORRECT — stored but slots are used for actual selection"),
    ("data.groomers[].availableSlots[]","array","[{startTime:'08:00',endTime:'09:00'}, ...]","YES — CRITICAL","Slot grid; setSelectedSlot() stores the chosen slot","CORRECT — slots come in 15-minute increments. Postman shows durationMinutes=60 → slots are 60min wide. Slot buttons show startTime only."),
    ("data.groomers[].availableSlots[].startTime","string","'08:00'","YES","Slot button label; stored in draft.timeSlot","CORRECT"),
    ("data.groomers[].availableSlots[].endTime","string","'09:00'","YES","Stored in draft.endTime via setSelectedSlot()","CORRECT"),
    ("image / photo / avatar (groomer)","—","NOT PRESENT in response","N/A","Flutter tries to read 7 key variants — all return null","DEAD CODE: Postman confirms no image field in groomers[]. Always shows initial letter. Remove the image key lookup."),
]
for row_data in resp_fields:
    field, ftype, val, reads, where, issue = row_data
    bg = GN if "CORRECT" in str(reads) else (RD if "DEAD" in str(issue) else (AM if "NO" in str(reads) else W))
    for ci, v in enumerate([field, ftype, val, reads, where, issue], 1):
        c = ws5.cell(r, ci); c.value = v
        if ci == 1: cell(c, D, W, True, 10, "left")
        else: cell(c, bg, D, False, 10, "left", ci in {3,5,6})
    ws5.row_dimensions[r].height = 32
    r += 1

widths(ws5, [45, 14, 36, 28, 45, 55])

# ════════════════════════════════════════════════════════════════════════════
# SHEET 6 — POST /api/availability confirmed
# ════════════════════════════════════════════════════════════════════════════
ws6 = wb.create_sheet("Availability API")
banner(ws6, 1, "POST /api/availability — Payload & Response CONFIRMED FROM POSTMAN", bg=T)
sub_banner(ws6, 2, "Postman request: serviceId=12, packageId=1, addOnIds=[2,3], groomerId=3")
r = 3

r = section(ws6, r, "REQUEST PAYLOAD — field by field", cols=5)
hdr(ws6, r, ["Field","Postman Value","Flutter Sends","Correct?","Notes"])
r += 1
req_fields = [
    ("ClientId","'SHEAR-001'","session.clientId ?? 'SHEAR-001'","PARTIAL","Hardcoded fallback always used because clientId is never extracted from login response. Fix: extract from login response data."),
    ("RegionId","'DWG-001'","session.regionId ?? 'DWG-001'","PARTIAL","Same issue — hardcoded."),
    ("StoreId","'SHEAR-001'","session.storeId ?? 'SHEAR-001'","PARTIAL","Same issue — hardcoded."),
    ("date","'2026-08-20'","DateFormat('yyyy-MM-dd').format(draft.date)","YES","Format YYYY-MM-DD confirmed correct."),
    ("serviceId","12 (integer)","extractServiceIds()['serviceId'] (int or null)","PARTIAL","For breed services with string IDs, this becomes null and serviceId is omitted. Must ensure breed service IDs are stored as integers."),
    ("packageId","1 (integer)","extractServiceIds()['packageId'] (int if >0)","YES","Sent when packageId > 0. Correct."),
    ("addOnIds","[2, 3] (int array)","extractAddOnIds() → List<int>","YES","Empty list omitted via conditional include. Correct."),
    ("groomerId","3 (integer); omit or 0 for no preference","int from draft.groomer['id']; 0 for 'any'","YES","Postman confirms groomerId=0 means 'pick any available groomer'. Flutter sends 0 for No Preference. Correct."),
]
for row_data in req_fields:
    field, pm_val, flutter_val, correct, notes = row_data
    bg = GN if correct=="YES" else (AM if correct=="PARTIAL" else RD)
    for ci, v in enumerate([field, pm_val, flutter_val, correct, notes], 1):
        c = ws6.cell(r, ci); c.value = v
        if ci == 1: cell(c, D, W, True, 10, "left")
        elif ci == 4: paint(ws6, r, ci, correct)
        else: cell(c, bg, D, False, 10, "left", ci in {3,5})
    ws6.row_dimensions[r].height = 32
    r += 1

r += 1
r = section(ws6, r, "RESPONSE FIELDS — confirmed from Postman response", cols=5)
hdr(ws6, r, ["Field","Type","Example Value","Flutter Uses It?","Notes"])
r += 1
resp_f = [
    ("success","bool","true","YES","Checked before parsing data."),
    ("data.date","string","'2026-08-20'","NO","Flutter uses date from draft. Fine."),
    ("data.closed","bool","false","NO","store.closed comes from groomer-availability instead. Fine — two sources agree."),
    ("data.holiday","null/string","null","NO","Same — groomer-availability provides this live."),
    ("data.totalDurationMinutes","int","60","YES — CRITICAL","Stored in draft.apiDurationMinutes. Drives Step 2 durationMinutes param. Correct."),
    ("data.totalPrice","int/float","64","YES","Stored in draft.apiTotalPrice. Shown on confirmed screen. Correct."),
    ("data.workingHours.day","string","'Thursday'","NO","Not used. Fine."),
    ("data.workingHours.open","string","'08:00'","NO","Backend uses this to compute slots. Not needed client-side."),
    ("data.workingHours.close","string","'17:30'","NO","Same."),
    ("data.workingHours.closed","bool","false","NO","Fine."),
    ("data.bookedSlots[]","array","[{bookingId:1, groomerId:3, startTime:'15:00', endTime:'16:00'}]","NO — CORRECT","Flutter doesn't need to manage booked slots. Backend uses these to exclude them from availableSlots. Not needed client-side."),
    ("data.availableSlots[]","array","[{startTime:'08:00', endTime:'09:00', groomerId:3, groomerName:'Jeremiah Smith'}, ...]","YES — in re-validate step","Step 1: slots NOT used (only totalDurationMinutes + totalPrice extracted). Re-validate: slots checked to confirm selected slot still available."),
    ("data.availableSlots[].startTime","string","'08:00'","YES","In re-validate: compared against draft.timeSlot."),
    ("data.availableSlots[].endTime","string","'09:00'","YES","In re-validate: compared against draft.endTime. Backend endTime used to correct if changed."),
    ("data.availableSlots[].groomerId","int","3","NO — in re-validate","Could be used to confirm groomer assignment. Currently not checked."),
    ("data.availableSlots[].groomerName","string","'Jeremiah Smith'","NO","Could be displayed on review screen."),
    ("data.groomers[]","array","[{id:3, name:'Jeremiah Smith', role:'...', workingHours:{...}, available:true}]","NO","Different structure from groomer-availability groomers[]. This is a summary only."),
]
for row_data in resp_f:
    field, ftype, ex, uses, notes = row_data
    bg = GN if "YES" in uses else (AM if "CORRECT" in uses or "NO" in uses else W)
    for ci, v in enumerate([field, ftype, ex, uses, notes], 1):
        c = ws6.cell(r, ci); c.value = v
        if ci == 1: cell(c, D, W, True, 10, "left")
        else: cell(c, bg, D, False, 10, "left", ci in {3,4,5})
    ws6.row_dimensions[r].height = 30
    r += 1

widths(ws6, [42, 14, 38, 30, 62])

# ════════════════════════════════════════════════════════════════════════════
# SHEET 7 — IMPLEMENTATION PLAN (ordered, actionable)
# ════════════════════════════════════════════════════════════════════════════
ws7 = wb.create_sheet("Implementation Plan")
banner(ws7, 1, "IMPLEMENTATION PLAN — Ordered by Priority")
sub_banner(ws7, 2, "Complete Phase 1 before anything else. Each task has one specific file and action.")
r = 3
hdr(ws7, r, ["Phase","#","Task","File(s)","Effort","Done?"])
r += 1

plan = [
    ("PHASE 1\nCritical", 1,
     "Extract clientId/regionId/storeId from login + verifyOtp response.\nCall session.saveClientId/RegionId/StoreId().\nRemove hardcoded 'SHEAR-001'/'DWG-001' fallbacks.",
     "auth_repository.dart → login() + verifyOtp()\nbooking_repository.dart (remove fallbacks)\nbooking_review_page_mobile.dart (remove fallbacks)",
     "1 hr",""),
    ("PHASE 1\nCritical", 2,
     "Fix createPet() pet ID extraction.\nChange response['id'] to response['data']?['pet']?['id'].",
     "pet_repository.dart → createPet()",
     "15 min",""),
    ("PHASE 1\nCritical", 3,
     "Implement GET /api/bookings → fix My Bookings.\nReplace getAllBookings/getUpcoming/getPast SQLite methods with API call.\nUpdate _BookingCard to read bookingDate, startTime, endTime, status, totalPrice from API.",
     "booking_repository.dart (add getBookingsFromApi)\nmy_bookings_page_mobile.dart (use API + fix _BookingCard + fix _statusChip)",
     "4 hrs",""),
    ("PHASE 1\nCritical", 4,
     "Fix breed service ID storage.\nStore integer IDs only in ServiceRepository.\nNever use 'breed_X_grooming' string as service ID.",
     "service_repository.dart → getBookingServices() Breeds section",
     "1 hr",""),
    ("PHASE 1\nCritical", 5,
     "Fix price storage in ServiceRepository.\nStore prices as double, not '$45' strings.\nFix estimatedTotal to show real price.",
     "service_repository.dart → all price fields\nbooking_draft.dart → estimatedTotal (or use apiTotalPrice)",
     "30 min",""),
    ("PHASE 2\nHigh", 6,
     "Fix 401 → redirect to login.\nAfter clearSession() in interceptor, navigate to login via GlobalKey<NavigatorState> or event bus.",
     "api_repository.dart → interceptor onError\napp.dart (register navKey)\nservices_locator.dart",
     "1 hr",""),
    ("PHASE 2\nHigh", 7,
     "Fix getPetById() response extraction.\nVerify /api/pets/:id response shape and extract data['pet'] correctly.",
     "pet_repository.dart → getPetById()",
     "30 min",""),
    ("PHASE 2\nHigh", 8,
     "Remove dead groomer image key lookup.\nPostman confirms no image field in groomers[]. Always show initial letter.",
     "booking_date_time_page_mobile.dart → groomer chip image builder",
     "15 min",""),
    ("PHASE 3\nAuth", 9,
     "Implement Forgot Password 3-step flow:\n1. Email input → POST /api/auth/send-otp\n2. OTP verify (reuse OtpPage)\n3. New password → POST /api/auth/reset-password (confirm endpoint with backend)",
     "forgot_password_page_mobile.dart (rebuild)\nauth_repository.dart (add forgotPassword + resetPassword)\nauth_bloc.dart (implement _onResetPasswordSubmitted)",
     "3 hrs",""),
    ("PHASE 4\nMedium", 10,
     "Fix duplicate serviceId+packageId in payload.\nFor packages: send only packageId, omit serviceId.",
     "booking_review_page_mobile.dart → _confirmBooking() createPayload\nbooking_repository.dart → getAvailability()",
     "30 min",""),
    ("PHASE 4\nMedium", 11,
     "Add user notice when Step 1 /api/availability fails.\nShow toast: 'Using estimated duration. Some slots may vary.'",
     "booking_date_time_page_mobile.dart → Step 1 failure branch",
     "15 min",""),
    ("PHASE 4\nMedium", 12,
     "Remove 5 SQLite dead methods: createBooking, updateBookingStatus, getBookedSlotsForDate, getBookingsForDate, getBookingById.",
     "booking_repository.dart",
     "30 min",""),
    ("PHASE 4\nMedium", 13,
     "Implement profile update.\nLoad user fields from session. Remove hardcoded phone. Add PUT /api/profile call (confirm endpoint with backend first).",
     "profile_page_mobile.dart\nauth_repository.dart",
     "2 hrs",""),
    ("PHASE 5\nLow", 14,
     "Reset BookingDraft at booking flow entry (PetSelectPage.initState or Book Now tap).",
     "pet_select_page_mobile.dart → initState()",
     "15 min",""),
    ("PHASE 5\nLow", 15,
     "Fix auth_bloc.dart: remove 'Demo OTP' log lines.",
     "auth_bloc.dart",
     "5 min",""),
    ("PHASE 5\nLow", 16,
     "Remove hardcoded $68/$40 price fallbacks in package cards.",
     "home_page_mobile.dart, packages_page_mobile.dart",
     "15 min",""),
    ("PHASE 5\nLow", 17,
     "Fix 'California' to 'Arlington, TX' or read from session user.",
     "home_page_mobile.dart → _buildHeader",
     "5 min",""),
    ("PHASE 5\nLow", 18,
     "Add delete confirmation dialog before DeletePet.",
     "my_pets_page_mobile.dart",
     "20 min",""),
    ("PHASE 5\nLow", 19,
     "Implement 'Add to Calendar' on BookingConfirmedPage.",
     "booking_confirmed_page_mobile.dart",
     "1 hr",""),
    ("PHASE 5\nLow", 20,
     "Fix 10 flutter analyze info warnings.",
     "booking_repository.dart, booking_review_page_mobile.dart, booking_confirmed_page_mobile.dart, home_page_mobile.dart, create_pet_page_mobile.dart, shared_calendar.dart",
     "30 min",""),
]

phase_bgs = {
    "PHASE 1": RD, "PHASE 2": OR, "PHASE 3": AM, "PHASE 4": AM, "PHASE 5": BL
}
for phase, num, task, files, effort, done in plan:
    ph_key = phase.split("\n")[0]
    row_bg = phase_bgs.get(ph_key, W)
    for ci, v in enumerate([phase, num, task, files, effort, done], 1):
        c = ws7.cell(r, ci); c.value = v
        if ci == 1:   cell(c, D, W, True, 9, "center", True)
        elif ci == 2: cell(c, row_bg, D, True, 12, "center")
        elif ci == 6:
            c.fill=F(W); c.border=bdr(); c.alignment=A("center","center")
        else:         cell(c, row_bg, D, False, 10, "left", ci in {3,4})
    ws7.row_dimensions[r].height = 52
    r += 1

widths(ws7, [16, 5, 70, 50, 10, 8])

# ════════════════════════════════════════════════════════════════════════════
# SAVE
# ════════════════════════════════════════════════════════════════════════════
out = r"d:\projects\shear_heaven_pet_spa\Shear_Heaven_Status_Report.xlsx"
wb.save(out)
print(f"Saved: {out}")
