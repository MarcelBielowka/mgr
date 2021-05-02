function SunPosition(year, month, day, hour; min=0, sec=0,
                        lat=50.29, long=19.08)

  twopi = 2 * pi
  deg2rad = pi / 180

  # Get day of the year, e.g. Feb 1 = 32, Mar 1 = 61 on leap years
  DaysOfMonth = [0,31,28,31,30,31,30,31,31,30,31,30]
  day = day + cumsum(DaysOfMonth)[month]
  if (year % 4 == 0 && (year % 400 == 0 || year % 100 != 0) &&
    day >= 60 && !(month==2 && day==60))
    day = day + 1
  end

  # Get Julian date - 2400000
  hour = hour + min / 60 + sec / 3600 # hour plus fraction
  delta = year - 1949
  leap = trunc(delta / 4) # former leapyears
  jd = 32916.5 + delta * 365 + leap + day + hour / 24

  # The input to the Astronomer's almanach is the difference between
  # the Julian date and JD 2451545.0 (noon, 1 January 2000)
  time = jd - 51545.

  # Ecliptic coordinates

  # Mean longitude
  mnlong = 280.460 + .9856474 * time
  mnlong = mnlong % 360
  if mnlong < 0
    mnlong = mnlong + 360
  end

  # Mean anomaly
  mnanom = 357.528 + .9856003 * time
  mnanom = mnanom % 360
  if mnanom < 0
    mnanom = mnanom + 360
  end

  mnanom = mnanom * deg2rad

  # Ecliptic longitude and obliquity of ecliptic
  eclong = mnlong + 1.915 * sin(mnanom) + 0.020 * sin(2 * mnanom)
  eclong = eclong % 360
  if eclong < 0
    eclong = eclong + 360
  end
  oblqec = 23.439 - 0.0000004 * time
  eclong = eclong * deg2rad
  oblqec = oblqec * deg2rad

  # Celestial coordinates
  # Right ascension and declination
  num = cos(oblqec) * sin(eclong)
  den = cos(eclong)
  ra = atan(num / den)
  if den < 0
    ra = ra + pi
  end
  if (den >= 0 && num < 0)
    ra = ra +twopi
  end
  dec = asin(sin(oblqec) * sin(eclong))

  # Local coordinates
  # Greenwich mean sidereal time
  gmst = 6.697375 + .0657098242 * time + hour
  gmst = gmst % 24
  if gmst < 0
    gmst = gmst + 24.
  end

  # Local mean sidereal time
  lmst = gmst + long / 15.
  lmst = lmst % 24.
  if lmst < 0
    lmst = lmst + 24.
  end
  lmst = lmst * 15. * deg2rad

  # Hour angle
  ha = lmst - ra
  if ha < -pi
    ha = ha + twopi
  end
  if ha > pi
    ha = ha - twopi
  end

  # Latitude to radians
  lat = lat * deg2rad

  # Azimuth and elevation
  el = asin(sin(dec) * sin(lat) + cos(dec) * cos(lat) * cos(ha))
  az = asin(-cos(dec) * sin(ha) / cos(el))

  # For logic and names, see Spencer, J.W. 1989. Solar Energy. 42(4):353
  cosAzPos = (0 <= sin(dec) - sin(el) * sin(lat))
  sinAzNeg = (sin(az) < 0)
  if (cosAzPos && sinAzNeg)
    az = az + twopi
  end

  if (!cosAzPos)
    az = pi - az
  end

  el = el / deg2rad
  az = az / deg2rad
  lat = lat / deg2rad

  return Dict(
    "elevation"=>el, "azimuth"=>az
  )
end
