import pymysql
import sys

def get_db():
    try:
        return pymysql.connect(
            host='127.0.0.1',
            user='bususer',
            password='buspassword',
            database='kolkata_bus_db',
            charset='utf8mb4'
        )
    except Exception:
        return pymysql.connect(
            user='wbsoumo',
            unix_socket='/tmp/mysql.sock',
            database='kolkata_bus_db',
            charset='utf8mb4'
        )

def main():
    conn = get_db()
    cur = conn.cursor()

    print("Creating Metro & Chat tables...")

    cur.execute("DROP TABLE IF EXISTS community_chat;")
    cur.execute("DROP TABLE IF EXISTS metro_stations;")
    cur.execute("DROP TABLE IF EXISTS metro_lines;")

    cur.execute("""
    CREATE TABLE metro_lines (
        line_id VARCHAR(20) PRIMARY KEY,
        line_number VARCHAR(10) NOT NULL,
        line_name VARCHAR(100) NOT NULL,
        line_color VARCHAR(20) NOT NULL,
        terminal_from VARCHAR(100) NOT NULL,
        terminal_to VARCHAR(100) NOT NULL,
        first_train VARCHAR(30) NOT NULL,
        last_train VARCHAR(30) NOT NULL,
        peak_headway VARCHAR(50) NOT NULL,
        offpeak_headway VARCHAR(50) NOT NULL,
        total_stations INT NOT NULL,
        special_feature VARCHAR(255)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    """)

    cur.execute("""
    CREATE TABLE metro_stations (
        id INT AUTO_INCREMENT PRIMARY KEY,
        line_id VARCHAR(20) NOT NULL,
        station_order INT NOT NULL,
        station_name VARCHAR(100) NOT NULL,
        station_bengali VARCHAR(100),
        distance_km DECIMAL(5,2) DEFAULT 0.0,
        interchange_info VARCHAR(255) DEFAULT '',
        gates_info VARCHAR(255) DEFAULT '',
        INDEX idx_line_order (line_id, station_order),
        INDEX idx_station_name (station_name),
        CONSTRAINT fk_metro_line FOREIGN KEY (line_id) REFERENCES metro_lines(line_id) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    """)

    cur.execute("""
    CREATE TABLE community_chat (
        id INT AUTO_INCREMENT PRIMARY KEY,
        channel VARCHAR(50) NOT NULL,
        user_name VARCHAR(50) NOT NULL,
        route_ref VARCHAR(50) DEFAULT '',
        status_tag VARCHAR(50) DEFAULT 'Normal',
        message TEXT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_channel (channel),
        INDEX idx_created (created_at)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    """)

    # Populate Metro Lines
    lines_data = [
        (
            'LINE_1', '1', 'Blue Line (North-South Corridor)', '#1976D2',
            'Dakshineswar', 'Kavi Subhash (New Garia)',
            '06:50 AM', '09:40 PM', 'Every 5-6 mins', 'Every 8-10 mins', 26,
            'First Metro Line in India (1984) connecting North & South Kolkata'
        ),
        (
            'LINE_2_WEST', '2', 'Green Line (Underwater Ganga Section)', '#2E7D32',
            'Howrah Maidan', 'Esplanade',
            '07:00 AM', '09:45 PM', 'Every 6-8 mins', 'Every 10-12 mins', 4,
            'India’s first underwater metro tunnel, passing 32m under the River Hooghly'
        ),
        (
            'LINE_2_EAST', '2', 'Green Line (East-West Sector V Section)', '#2E7D32',
            'Sealdah', 'Salt Lake Sector V',
            '06:55 AM', '09:40 PM', 'Every 8-10 mins', 'Every 12-15 mins', 8,
            'Major IT Hub corridor connecting Sealdah Station to Salt Lake Sector V'
        ),
        (
            'LINE_3', '3', 'Purple Line (Southwest Corridor)', '#7B1FA2',
            'Joka', 'Majerhat',
            '08:30 AM', '04:30 PM', 'Every 20 mins', 'Every 25 mins', 7,
            'Servicing Diamond Harbour Road and Southwest suburbs'
        ),
        (
            'LINE_6', '6', 'Orange Line (EM Bypass Corridor)', '#E65100',
            'Kavi Subhash (New Garia)', 'Hemanta Mukhopadhyay (Ruby)',
            '09:00 AM', '04:40 PM', 'Every 20 mins', 'Every 25 mins', 5,
            'EM Bypass connection towards Kolkata NSCBIA Airport'
        )
    ]

    line_sql = """
    INSERT INTO metro_lines (line_id, line_number, line_name, line_color, terminal_from, terminal_to, first_train, last_train, peak_headway, offpeak_headway, total_stations, special_feature)
    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
    """
    cur.executemany(line_sql, lines_data)

    # Populate Line 1 Stations (26 Stations)
    line1_stations = [
        (1, 'Dakshineswar', 'দক্ষিণেশ্বর', 0.0, 'Dakshineswar Kali Temple Hub', 'Gate 1: Temple, Gate 2: PWD Rd'),
        (2, 'Baranagar', 'বরানগর', 1.8, 'BT Road Bus Interchanges', 'Gate 1: Dunlop, Gate 2: BT Road'),
        (3, 'Noapara', 'নোয়াপাড়া', 4.1, 'Depot Terminal & Car Shed', 'Gate 1: Noapara, Gate 2: Dum Dum Cantonment'),
        (4, 'Dum Dum', 'দমদম', 6.2, 'Eastern Railway Suburban Interchanges', 'Gate 1: Railway Platform 1, Gate 2: Station Road'),
        (5, 'Belgachia', 'বেলগাছিয়া', 8.5, 'RG Kar Hospital connection', 'Gate 1: RG Kar Rd, Gate 2: Milk Colony'),
        (6, 'Shyambazar', 'শ্যামবাজার', 10.1, 'Five-point Crossing Bus Hub', 'Gate 1: Bhupen Bose Ave, Gate 2: Cornwallis St'),
        (7, 'Shovabazar Sutanuti', 'শোভাবাজার সুতানুটি', 11.4, 'North Kolkata Heritage Ghats', 'Gate 1: BK Paul Ave, Gate 2: Sovabazar Rajbari'),
        (8, 'Girish Park', 'গিরিশ পার্ক', 12.3, 'CR Avenue Commercial Hub', 'Gate 1: Girish Park, Gate 2: Vivekananda Rd'),
        (9, 'Mahatma Gandhi Road', 'মহাত্মা গান্ধী রোড', 13.2, 'Burrabazar & Sealdah Link', 'Gate 1: MG Road, Gate 2: College Street Market'),
        (10, 'Central', 'সেন্ট্রাল', 14.1, 'Medical College & Bowbazar', 'Gate 1: Medical College, Gate 2: BB Ganguly St'),
        (11, 'Chandni Chowk', 'চাঁদনি চক', 14.8, 'Electronics Market & E-Mall', 'Gate 1: E-Mall, Gate 2: Ganesh Chandra Ave'),
        (12, 'Esplanade', 'এসপ্ল্যানেড', 15.6, 'Interchange with Line 2 (Green) & Line 3 (Purple)', 'Gate 1: Bus Terminus, Gate 2: Curzon Park, Gate 3: New Market'),
        (13, 'Park Street', 'পার্ক স্ট্রিট', 16.4, 'Park Street Restaurants & Asiatic Society', 'Gate 1: Park Street, Gate 2: Jawaharlal Nehru Rd'),
        (14, 'Maidan', 'ময়দান', 17.2, 'Brigade Parade Ground & Eden Gardens', 'Gate 1: Maidan, Gate 2: Victoria Memorial Walk'),
        (15, 'Rabindra Sadan', 'রবীন্দ্র সদন', 17.9, 'Nandan, Academy & Exide More', 'Gate 1: Exide Crossing, Gate 2: AJC Bose Rd'),
        (16, 'Netaji Bhavan', 'নেতাজি ভবন', 18.7, 'Netaji Research Bureau, Bhowanipore', 'Gate 1: Ashutosh Mukherjee Rd, Gate 2: Elgin Rd'),
        (17, 'Jatin Das Park', 'যতীন দাস পার্ক', 19.9, 'Hazra More Bus Intersection', 'Gate 1: Hazra Rd, Gate 2: SP Mukherjee Rd'),
        (18, 'Kalighat', 'কালীঘাট', 21.0, 'Kalighat Kali Temple & Rashbehari', 'Gate 1: Rashbehari Crossing, Gate 2: Temple Approach'),
        (19, 'Rabindra Sarobar', 'রবীন্দ্র সরোবর', 22.1, 'Dhakuria Lakes & Charu Market', 'Gate 1: Southern Ave, Gate 2: Tollygunge Phari'),
        (20, 'Mahanayak Uttam Kumar', 'মহানায়ক উত্তম কুমার', 23.4, 'Tollygunge Tram & Bus Terminus', 'Gate 1: Deshapran Sasmal Rd, Gate 2: Prince Anwar Shah Rd'),
        (21, 'Netaji', 'নেতাজি', 24.6, 'Kudghat Bus Stand', 'Gate 1: Kudghat, Gate 2: Chandi Ghosh Rd'),
        (22, 'Masterda Surya Sen', 'মাস্টারদা সূর্য সেন', 26.2, 'Bansdroni Transit Point', 'Gate 1: NSC Bose Rd, Gate 2: Bansdroni Bazar'),
        (23, 'Gitanjali', 'গীতাঞ্জলি', 27.5, 'Naktala Hub', 'Gate 1: Naktala, Gate 2: NSC Bose Rd'),
        (24, 'Kavi Nazrul', 'কবি নজরুল', 28.7, 'Garia Bazar & Bus Stand', 'Gate 1: Garia Bazar, Gate 2: Raja SC Mullick Rd'),
        (25, 'Shahid Khudiram', 'শহীদ ক্ষুদিরাম', 30.1, 'Dhalai Bridge & EM Bypass', 'Gate 1: EM Bypass, Gate 2: Dhalai Bridge'),
        (26, 'Kavi Subhash', 'কবি সুভাষ', 31.4, 'Interchange with Line 6 (Orange) & Sealdah South Local Trains', 'Gate 1: New Garia Railway Stn, Gate 2: EM Bypass Bus Stand')
    ]

    # Populate Line 2 West (Underwater Section - 4 Stations)
    line2_west_stations = [
        (1, 'Howrah Maidan', 'হাওড়া ময়দান', 0.0, 'Howrah District Court & Bus Terminus', 'Gate 1: Maidan, Gate 2: GT Road'),
        (2, 'Howrah', 'হাওড়া', 1.4, 'Deepest Metro Station in India (30m) • Direct Howrah Railway Station Platforms', 'Gate 1: Howrah Stn Concours, Gate 2: Bus Terminus, Gate 3: Ferry Ghat'),
        (3, 'BBD Bagh (Mahakaran)', 'মহাকরণ', 3.0, 'Writers Building, Lalbazar & Brabourne Rd', 'Gate 1: Writers Bldg, Gate 2: Strand Road, Gate 3: Fairlie Ghat'),
        (4, 'Esplanade', 'এসপ্ল্যানেড', 4.8, 'Direct Interchange with Line 1 (Blue) & Central Bus Terminus', 'Gate 1: Esplanade Central, Gate 2: New Market, Gate 3: Curzon Park')
    ]

    # Populate Line 2 East (Salt Lake Sector V Section - 8 Stations)
    line2_east_stations = [
        (1, 'Sealdah', 'শিয়ালদহ', 0.0, 'Direct Interchange with Eastern Railway Sealdah Station', 'Gate 1: Sealdah Railway Stn, Gate 2: AJC Bose Rd'),
        (2, 'Phoolbagan', 'ফুলবাগান', 2.1, 'Beliaghata & EM Bypass Link', 'Gate 1: Phoolbagan Crossing, Gate 2: CIT Road'),
        (3, 'Salt Lake Stadium', 'সল্টলেক স্টেডিয়াম', 3.7, 'Vivekananda Yuba Bharati Krirangan', 'Gate 1: Stadium Gate 1, Gate 2: EM Bypass'),
        (4, 'Bengal Chemical', 'বেঙ্গল কেমিক্যাল', 5.0, 'Mani Square Mall & Apollo Hospital', 'Gate 1: Mani Square, Gate 2: EM Bypass'),
        (5, 'City Centre', 'সিটি সেন্টার', 6.4, 'City Centre 1 Mall & Salt Lake DC Block', 'Gate 1: CC1 Mall, Gate 2: Block DC'),
        (6, 'Central Park', 'সেন্ট্রাল পার্ক', 7.5, 'Salt Lake Fairgrounds & Bikash Bhavan', 'Gate 1: Fairgrounds, Gate 2: Bikash Bhavan'),
        (7, 'Karunamoyee', 'করুণাময়ী', 8.5, 'International Bus Terminus & Salt Lake Sub-Division', 'Gate 1: Bus Terminus, Gate 2: Sub-Divisional Hospital'),
        (8, 'Salt Lake Sector V', 'সল্টলেক সেক্টর ৫', 9.8, 'Kolkata IT Tech Hub, RDB Boulevard, Wipro More', 'Gate 1: RDB Cinema, Gate 2: Ring Road, Gate 3: College More')
    ]

    # Populate Line 3 (Purple Line - 7 Stations)
    line3_stations = [
        (1, 'Joka', 'জোকা', 0.0, 'IIM Calcutta Terminal', 'Gate 1: Diamond Harbour Rd, Gate 2: IIM Gate'),
        (2, 'Thakurpukur', 'ঠাকুরপুকুর', 1.5, 'Thakurpukur Cancer Hospital', 'Gate 1: Cancer Hospital, Gate 2: DH Road'),
        (3, 'Sakher Bazar', 'সখের বাজার', 2.7, 'Sakher Bazar Commercial', 'Gate 1: DH Road, Gate 2: Diamond Park'),
        (4, 'Behala Chowrasta', 'বেহালা চৌরাস্তা', 4.1, 'Behala Major Bus Interchange', 'Gate 1: Chowrasta Crossing, Gate 2: James Long Sarani'),
        (5, 'Behala Bazar', 'বেহালা বাজার', 5.4, 'Behala Tram Depot & Market', 'Gate 1: Bazar, Gate 2: Tram Depot'),
        (6, 'Taratala', 'তারাতলা', 6.8, 'Taratala Industrial Area & Majerhat Link', 'Gate 1: Taratala Crossing, Gate 2: Hide Road'),
        (7, 'Majerhat', 'মাঝেরহাট', 8.0, 'Interchange with Sealdah South Suburban Railway', 'Gate 1: Railway Station, Gate 2: Majerhat Bridge')
    ]

    # Populate Line 6 (Orange Line - 5 Stations)
    line6_stations = [
        (1, 'Kavi Subhash', 'কবি সুভাষ', 0.0, 'Interchange with Line 1 (Blue) & New Garia Railway Station', 'Gate 1: Blue Line Concourse, Gate 2: Railway Stn'),
        (2, 'Satyajit Ray', 'সত্যজিৎ রায়', 1.6, 'SRFTI Film Institute & Hiland Park', 'Gate 1: SRFTI, Gate 2: EM Bypass'),
        (3, 'Jyotirindra Nandy', 'জ্যোতিরিন্দ্র নন্দী', 3.0, 'Mukundapur Hospitals (RN Tagore, Peerless)', 'Gate 1: RN Tagore Hospital, Gate 2: Peerless Link'),
        (4, 'Kavi Sukanta', 'কবি সুকান্ত', 4.2, 'Kalikapur Crossing & Metro Cash & Carry', 'Gate 1: Kalikapur, Gate 2: EM Bypass'),
        (5, 'Hemanta Mukhopadhyay (Ruby)', 'হেমন্ত মুখোপাধ্যায়', 5.4, 'Ruby General Hospital & Anandapur Hub', 'Gate 1: Ruby Hospital Crossing, Gate 2: Rajdanga Main Rd')
    ]

    stn_sql = """
    INSERT INTO metro_stations (line_id, station_order, station_name, station_bengali, distance_km, interchange_info, gates_info)
    VALUES (%s, %s, %s, %s, %s, %s, %s)
    """

    for s in line1_stations:
        cur.execute(stn_sql, ('LINE_1', s[0], s[1], s[2], s[3], s[4], s[5]))

    for s in line2_west_stations:
        cur.execute(stn_sql, ('LINE_2_WEST', s[0], s[1], s[2], s[3], s[4], s[5]))

    for s in line2_east_stations:
        cur.execute(stn_sql, ('LINE_2_EAST', s[0], s[1], s[2], s[3], s[4], s[5]))

    for s in line3_stations:
        cur.execute(stn_sql, ('LINE_3', s[0], s[1], s[2], s[3], s[4], s[5]))

    for s in line6_stations:
        cur.execute(stn_sql, ('LINE_6', s[0], s[1], s[2], s[3], s[4], s[5]))

    # Seed initial community chat messages
    chat_seed = [
        ('general', 'Souvik_HWH', 'Howrah Hub', 'Moving Smooth', 'Howrah Station bus stand moving normally this evening. 215A and S12 lined up at Bay 2.'),
        ('general', 'Priya_SaltLake', 'Route 215A', 'Normal', 'Boarded 215A from Sector V towards Howrah. Light traffic near Karunamoyee.'),
        ('metro', 'Anirban_Kolkata', 'Line 2 Green', 'Normal', 'Underwater metro from Howrah to Esplanade took just 6 mins! Super clean and cool.'),
        ('general', 'Debjit_Garia', 'EM Bypass', 'Heavy Jam', 'Slow moving traffic near Ruby Crossing due to road maintenance work. Avoid if heading to Airport.')
    ]

    chat_sql = """
    INSERT INTO community_chat (channel, user_name, route_ref, status_tag, message)
    VALUES (%s, %s, %s, %s, %s)
    """
    cur.executemany(chat_sql, chat_seed)

    conn.commit()
    cur.close()
    conn.close()

    print("SUCCESS: Populated 5 Metro Corridors, 50 Metro Stations, and Commuter Chat in MySQL!")

if __name__ == '__main__':
    main()

