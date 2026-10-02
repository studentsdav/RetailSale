import { Request, Response } from 'express';
import { Op } from 'sequelize';

export const INDIAN_STATES: string[] = [
    'Andaman and Nicobar Islands',
    'Andhra Pradesh',
    'Arunachal Pradesh',
    'Assam',
    'Bihar',
    'Chandigarh',
    'Chhattisgarh',
    'Dadra and Nagar Haveli and Daman and Diu',
    'Delhi',
    'Goa',
    'Gujarat',
    'Haryana',
    'Himachal Pradesh',
    'Jammu and Kashmir',
    'Jharkhand',
    'Karnataka',
    'Kerala',
    'Ladakh',
    'Lakshadweep',
    'Madhya Pradesh',
    'Maharashtra',
    'Manipur',
    'Meghalaya',
    'Mizoram',
    'Nagaland',
    'Odisha',
    'Puducherry',
    'Punjab',
    'Rajasthan',
    'Sikkim',
    'Tamil Nadu',
    'Telangana',
    'Tripura',
    'Uttar Pradesh',
    'Uttarakhand',
    'West Bengal'
];

export const US_STATES: string[] = [
    'Alabama',
    'Alaska',
    'Arizona',
    'Arkansas',
    'California',
    'Colorado',
    'Connecticut',
    'Delaware',
    'District of Columbia',
    'Florida',
    'Georgia',
    'Guam',
    'Hawaii',
    'Idaho',
    'Illinois',
    'Indiana',
    'Iowa',
    'Kansas',
    'Kentucky',
    'Louisiana',
    'Maine',
    'Maryland',
    'Massachusetts',
    'Michigan',
    'Minnesota',
    'Mississippi',
    'Missouri',
    'Montana',
    'Nebraska',
    'Nevada',
    'New Hampshire',
    'New Jersey',
    'New Mexico',
    'New York',
    'North Carolina',
    'North Dakota',
    'Ohio',
    'Oklahoma',
    'Oregon',
    'Pennsylvania',
    'Puerto Rico',
    'Rhode Island',
    'South Carolina',
    'South Dakota',
    'Tennessee',
    'Texas',
    'Utah',
    'Vermont',
    'Virgin Islands',
    'Virginia',
    'Washington',
    'West Virginia',
    'Wisconsin',
    'Wyoming'
];

export const KENYA_COUNTIES: string[] = [
    'Baringo',
    'Bomet',
    'Bungoma',
    'Busia',
    'Elgeyo-Marakwet',
    'Embu',
    'Garissa',
    'Homa Bay',
    'Isiolo',
    'Kajiado',
    'Kakamega',
    'Kericho',
    'Kiambu',
    'Kilifi',
    'Kirinyaga',
    'Kisii',
    'Kisumu',
    'Kitui',
    'Kwale',
    'Laikipia',
    'Lamu',
    'Machakos',
    'Makueni',
    'Mandera',
    'Marsabit',
    'Meru',
    'Migori',
    'Mombasa',
    "Murang'a",
    'Nairobi',
    'Nakuru',
    'Nandi',
    'Narok',
    'Nyamira',
    'Nyandarua',
    'Nyeri',
    'Samburu',
    'Siaya',
    'Taita-Taveta',
    'Tana River',
    'Tharaka-Nithi',
    'Trans-Nzoia',
    'Turkana',
    'Uasin Gishu',
    'Vihiga',
    'Wajir',
    'West Pokot'
];

export const UK_REGIONS: string[] = [
    'East Midlands',
    'East of England',
    'Greater London',
    'North East',
    'North West',
    'Northern Ireland',
    'Scotland',
    'South East',
    'South West',
    'Wales',
    'West Midlands',
    'Yorkshire and the Humber'
];

export const CANADA_PROVINCES: string[] = [
    'Alberta',
    'British Columbia',
    'Manitoba',
    'New Brunswick',
    'Newfoundland and Labrador',
    'Northwest Territories',
    'Nova Scotia',
    'Nunavut',
    'Ontario',
    'Prince Edward Island',
    'Quebec',
    'Saskatchewan',
    'Yukon'
];

export const UAE_EMIRATES: string[] = [
    'Abu Dhabi',
    'Ajman',
    'Dubai',
    'Fujairah',
    'Ras Al Khaimah',
    'Sharjah',
    'Umm Al-Quwain'
];

export function normalizeCountryCode(countryRaw?: string): string {
    const c = (countryRaw || '').toString().trim().toUpperCase();
    if (!c) return '';
    if (c === 'US' || c === 'USA' || c === 'UNITED STATES' || c === 'UNITED STATES OF AMERICA') return 'US';
    if (c === 'IN' || c === 'IND' || c === 'INDIA') return 'IN';
    if (c === 'KE' || c === 'KEN' || c === 'KENYA') return 'KE';
    if (c === 'GB' || c === 'UK' || c === 'UNITED KINGDOM' || c === 'GREAT BRITAIN') return 'GB';
    if (c === 'AE' || c === 'UAE' || c === 'UNITED ARAB EMIRATES') return 'AE';
    if (c === 'CA' || c === 'CAN' || c === 'CANADA') return 'CA';
    if (c === 'AU' || c === 'AUS' || c === 'AUSTRALIA') return 'AU';
    if (c === 'TZ' || c === 'TZA' || c === 'TANZANIA') return 'TZ';
    if (c === 'UG' || c === 'UGA' || c === 'UGANDA') return 'UG';
    if (c === 'RW' || c === 'RWA' || c === 'RWANDA') return 'RW';
    if (c === 'ZA' || c === 'ZAF' || c === 'SOUTH AFRICA') return 'ZA';
    if (c === 'NG' || c === 'NGA' || c === 'NIGERIA') return 'NG';
    return c;
}

export const getStates = async (req: Request, res: Response) => {
    try {
        const outlet_id = (req as any).user?.outlet_id;
        const requestedRaw = (req.query.country_code || req.query.country || '').toString().trim();
        const countryCode = normalizeCountryCode(requestedRaw);

        const customStates = await (req as any).propertyDb.models.custom_states.findAll({
            where: {
                outlet_id,
                is_active: true
            },
            order: [['state_name', 'ASC']]
        });

        let basePresetStates: string[] = [];
        if (countryCode === 'US') {
            basePresetStates = US_STATES;
        } else if (countryCode === 'IN') {
            basePresetStates = INDIAN_STATES;
        } else if (countryCode === 'KE') {
            basePresetStates = KENYA_COUNTIES;
        } else if (countryCode === 'GB') {
            basePresetStates = UK_REGIONS;
        } else if (countryCode === 'CA') {
            basePresetStates = CANADA_PROVINCES;
        } else if (countryCode === 'AE') {
            basePresetStates = UAE_EMIRATES;
        }

        const stateSet = new Set<string>(basePresetStates);

        // Filter custom states matching the country code
        customStates
            .filter((s: any) => {
                const sCountry = normalizeCountryCode(s.country_code);
                return !countryCode || sCountry === countryCode;
            })
            .forEach((s: any) => stateSet.add(s.state_name));

        const stateNames = Array.from(stateSet).sort();

        res.json({
            success: true,
            country_code: countryCode || 'US',
            is_india: countryCode === 'IN',
            states: stateNames,
            custom_records: customStates
        });
    } catch (err: any) {
        console.error('Error fetching states:', err);
        res.status(500).json({ success: false, error: err.message });
    }
};

export const createState = async (req: Request, res: Response) => {
    try {
        const outlet_id = (req as any).user?.outlet_id;
        const { state_name, state_code, country_code } = req.body;

        const cleanName = (state_name || '').toString().trim();
        const cleanCountry = normalizeCountryCode(country_code) || 'US';
        const cleanCode = state_code ? state_code.toString().trim() : null;

        if (!cleanName) {
            return res.status(400).json({ success: false, message: 'State / Region name is required' });
        }

        // Check if already exists in custom_states
        let state = await (req as any).propertyDb.models.custom_states.findOne({
            where: {
                outlet_id,
                country_code: cleanCountry,
                state_name: { [Op.iLike]: cleanName }
            }
        });

        if (state) {
            if (!state.is_active) {
                await state.update({ is_active: true, state_code: cleanCode || state.state_code });
            }
            return res.json({
                success: true,
                message: 'State already available',
                data: state
            });
        }

        state = await (req as any).propertyDb.models.custom_states.create({
            outlet_id,
            country_code: cleanCountry,
            state_name: cleanName,
            state_code: cleanCode,
            is_custom: true,
            is_active: true
        });

        res.json({
            success: true,
            message: `Custom region/state "${cleanName}" saved successfully in database`,
            data: state
        });
    } catch (err: any) {
        console.error('Error creating custom state:', err);
        res.status(400).json({ success: false, error: err.message });
    }
};

export const deleteState = async (req: Request, res: Response) => {
    try {
        const outlet_id = (req as any).user?.outlet_id;
        const { id } = req.params;

        const state = await (req as any).propertyDb.models.custom_states.findOne({
            where: { id, outlet_id }
        });

        if (!state) {
            return res.status(404).json({ success: false, message: 'State not found' });
        }

        await state.destroy();
        res.json({ success: true, message: 'Custom state deleted successfully' });
    } catch (err: any) {
        res.status(400).json({ success: false, error: err.message });
    }
};

export default {
    INDIAN_STATES,
    US_STATES,
    KENYA_COUNTIES,
    UK_REGIONS,
    CANADA_PROVINCES,
    UAE_EMIRATES,
    normalizeCountryCode,
    getStates,
    createState,
    deleteState
};

module.exports = {
    INDIAN_STATES,
    US_STATES,
    KENYA_COUNTIES,
    UK_REGIONS,
    CANADA_PROVINCES,
    UAE_EMIRATES,
    normalizeCountryCode,
    getStates,
    createState,
    deleteState
};
